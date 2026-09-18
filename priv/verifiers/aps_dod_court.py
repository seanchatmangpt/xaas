#!/usr/bin/env python3
"""Fabric-side Chicago-school definition-of-done court for APS work items.

The worker that produced a candidate never runs, edits, or vouches for this
court. Given a git worktree, the exact head the worker claims, and an
operator-written ticket (outside the worktree), it decides ALIVE / REFUSED /
BLOCKED as a pure function of gate results and emits ONE APS evidence receipt
(contracts/evidence-receipt.schema.json) as the last stdout line.

    python3 aps_dod_court.py --worktree PATH --head SHA --ticket PATH \
        --executor WORKER_ID --verifier-identity ID [--mdbook-out DIR]

Exit codes: 0 all gates pass (ALIVE); 1 a gate failed (REFUSED for the safety
gates, BLOCKED otherwise); 2 the court could not run (infra, bad ticket, bad
receipt) - never 0 on doubt.

Every tree-dependent gate runs against a `git archive` export of --head, so
the worktree is never written to, and exactness of the evidence subject holds
by construction. Candidate code is executed (tests, verify.py): this is
RCE-equivalent and relies on the caller's env allowlist and containment.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import io
import json
import os
import re
import shutil
import signal
import site
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid
from pathlib import Path

COURT_VERSION = "aps-dod-court/1"
TICKET_SCHEMA = "aps-ticket/1"

SAFETY_GATES = {"CHI-EXACT-HEAD", "CHI-INDEPENDENT", "CHI-SCOPE", "CHI-MOCK"}

PROTECTED = [
    "tools/verify.py",
    "tools/verify_ggen_ecosystem.py",
    "tools/simulate_fortune500.py",
    "tools/requirements-ci.txt",
    "MANIFEST.json",
    ".aps-syntax.md",
    "AGENTS.md",
    "CLAUDE.md",
    ".github/**",
    ".claude/**",
    "contracts/**",
    "ontology/**",
    "archive/**",
    "specification-guide/**",
    "examples/**",
    "simulation/**",
]

# The Chicago rule's grep, verbatim in intent: no test double machinery.
MOCK_PATTERNS = [
    r"unittest\.mock",
    r"Mock\(",
    r"MagicMock",
    r"patch\(",
    r"monkeypatch",
    r"from unittest import mock",
    r"import mock",
    r"mocker",
]
MOCK_RE = re.compile("|".join(MOCK_PATTERNS))

# In-process test runner: writes per-test outcomes as JSON to argv[1] so the
# court never parses verbose text. argv[2:] are module stems under tests/.
RUNNER = r'''
import json, sys, unittest

class R(unittest.TestResult):
    def __init__(self):
        super().__init__()
        self.rows = []
    def _row(self, t, outcome, msg=""):
        self.rows.append({"id": t.id(), "outcome": outcome, "msg": str(msg)[-600:]})
    def addSuccess(self, t):
        super().addSuccess(t); self._row(t, "ok")
    def addFailure(self, t, e):
        super().addFailure(t, e); self._row(t, "fail", self._exc_info_to_string(e, t))
    def addError(self, t, e):
        super().addError(t, e); self._row(t, "error", self._exc_info_to_string(e, t))
    def addSkip(self, t, reason):
        super().addSkip(t, reason); self._row(t, "skipped", reason)
    def addExpectedFailure(self, t, e):
        super().addExpectedFailure(t, e); self._row(t, "skipped", "expected failure")
    def addUnexpectedSuccess(self, t):
        super().addUnexpectedSuccess(t); self._row(t, "fail", "unexpected success")
    def addSubTest(self, test, subtest, err):
        super().addSubTest(test, subtest, err)
        if err is not None:
            self._row(test, "fail", self._exc_info_to_string(err, test))

out = sys.argv[1]
sys.path.insert(0, "tests")
suite = unittest.TestLoader().loadTestsFromNames(sys.argv[2:])
r = R()
r.buffer = True
suite.run(r)
with open(out, "w") as fh:
    json.dump({"rows": r.rows, "ran": r.testsRun, "ok": r.wasSuccessful()}, fh)
sys.exit(0 if r.wasSuccessful() else 1)
'''


class TicketError(Exception):
    pass


class Infra(Exception):
    pass


# ----------------------------------------------------------------- helpers
def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(obj) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def tail(text: str, n: int = 1500) -> str:
    return text if len(text) <= n else "..." + text[-n:]


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def child_env(home: Path) -> dict:
    env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": str(home),
        "LANG": os.environ.get("LANG", "C.UTF-8"),
        "PYTHONDONTWRITEBYTECODE": "1",
        # HOME is a throwaway; keep the interpreter's own user-site packages reachable.
        "PYTHONUSERBASE": site.getuserbase(),
        "GIT_OPTIONAL_LOCKS": "0",
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull,
    }
    return env


def run_cmd(cmd, cwd, env, timeout):
    """Run cmd in its own session with output redirected to temp files.

    Returns (rc, stdout_tail, stderr_tail, ms, timed_out). rc is None on timeout.
    A missing executable raises Infra."""
    started = time.monotonic()
    with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
        try:
            proc = subprocess.Popen(
                cmd, cwd=str(cwd), env=env, stdout=out, stderr=err,
                stdin=subprocess.DEVNULL, start_new_session=True,
            )
        except FileNotFoundError as exc:
            raise Infra(f"executable not found: {cmd[0]}") from exc
        timed_out = False
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            proc.wait()
        ms = int((time.monotonic() - started) * 1000)

        def read_tail(fh):
            size = fh.seek(0, os.SEEK_END)
            fh.seek(max(0, size - 6000))
            return fh.read().decode("utf-8", errors="replace")

        return (None if timed_out else proc.returncode, read_tail(out), read_tail(err), ms, timed_out)


def git(worktree, *args, env, check=True, binary=False):
    proc = subprocess.run(
        ["git", "-C", str(worktree), *args],
        env=env, capture_output=True, stdin=subprocess.DEVNULL,
    )
    if check and proc.returncode != 0:
        raise Infra(f"git {' '.join(args)} failed: {proc.stderr.decode(errors='replace').strip()[:300]}")
    return proc if binary else (proc.returncode, proc.stdout.decode("utf-8", errors="replace"))


def glob_to_re(pattern: str):
    out, i = [], 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("^" + "".join(out) + "$")


def matches_any(path: str, patterns) -> bool:
    return any(glob_to_re(p).match(path) for p in patterns)


def result(gate_id, ok, detail, kind=None, **extra):
    return {"id": gate_id, "pass": bool(ok), "kind": kind or ("ok" if ok else "fail"),
            "detail": tail(str(detail), 2000), **extra}


def skipped(gate_id, why):
    return result(gate_id, False, f"skipped: {why}", kind="skipped")


# ----------------------------------------------------------------- ticket
def load_ticket(path: str) -> dict:
    try:
        raw = Path(path).read_text()
        t = json.loads(raw)
    except (OSError, ValueError) as exc:
        raise TicketError(f"ticket unreadable: {exc}") from exc
    if not isinstance(t, dict):
        raise TicketError("ticket must be a JSON object")
    if t.get("schemaVersion") != TICKET_SCHEMA:
        raise TicketError(f"ticket schemaVersion must be {TICKET_SCHEMA!r}")
    if not isinstance(t.get("item"), str) or not re.fullmatch(r"[A-Za-z0-9._:-]+", t["item"]):
        raise TicketError("ticket item must match [A-Za-z0-9._:-]+")
    if not isinstance(t.get("attempt"), int) or isinstance(t["attempt"], bool) or t["attempt"] < 0:
        raise TicketError("ticket attempt must be an integer >= 0")
    if not isinstance(t.get("base_sha"), str) or not re.fullmatch(r"[0-9a-f]{40}", t["base_sha"]):
        raise TicketError("ticket base_sha must be 40 lowercase hex")
    ap = t.get("allowed_paths")
    if not isinstance(ap, list) or not ap or not all(isinstance(p, str) and p for p in ap):
        raise TicketError("ticket allowed_paths must be a non-empty list of strings")
    mnt = t.setdefault("min_new_tests", 3)
    if not isinstance(mnt, int) or isinstance(mnt, bool) or mnt < 1:
        raise TicketError("ticket min_new_tests must be an integer >= 1")
    mkr = t.setdefault("min_kill_ratio", 1.0)
    if not isinstance(mkr, (int, float)) or isinstance(mkr, bool) or not (0 < mkr <= 1):
        raise TicketError("ticket min_kill_ratio must be in (0, 1]")
    muts = t.get("mutants")
    if not isinstance(muts, list):
        raise TicketError("ticket mutants must be a list")
    for m in muts:
        if not (isinstance(m, dict) and isinstance(m.get("id"), str) and isinstance(m.get("kind"), str)
                and isinstance(m.get("file"), str)):
            raise TicketError("each mutant needs string id, kind and file")
        f = m["file"]
        if f.startswith("/") or ".." in Path(f).parts or not f:
            raise TicketError(f"mutant file must be a relative path inside the tree: {f!r}")
    if t.get("history") is not None and not isinstance(t["history"], list):
        raise TicketError("ticket history must be a list")
    return t


# ------------------------------------------------------------------ export
def export_head(worktree: Path, head: str, dest: Path, env) -> None:
    proc = git(worktree, "archive", "--format=tar", head, env=env, binary=True)
    dest.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(proc.stdout)) as tar:
        tar.extractall(dest, filter="data")


def parse_raw_diff(worktree: Path, base: str, head: str, env):
    proc = git(worktree, "diff", "--raw", "--no-renames", "-z", base, head, env=env, binary=True)
    tokens = proc.stdout.decode("utf-8", errors="replace").split("\0")
    entries, i = [], 0
    while i < len(tokens):
        tok = tokens[i]
        if tok.startswith(":"):
            parts = tok[1:].split()
            entries.append({"oldmode": parts[0], "newmode": parts[1], "status": parts[4][0], "path": tokens[i + 1]})
            i += 2
        else:
            i += 1
    return entries


# ------------------------------------------------------------------- gates
def gate_independent(executor: str, verifier: str):
    if not executor.strip() or not verifier.strip():
        return result("CHI-INDEPENDENT", False, "executor and verifier identities must both be non-empty")
    if executor.strip() == verifier.strip():
        return result("CHI-INDEPENDENT", False, f"executor == verifier ({executor!r}); the court cannot self-attest")
    return result("CHI-INDEPENDENT", True, "executor and verifier identities differ")


def gate_scope(entries, ticket):
    problems = []
    for e in entries:
        path, status = e["path"], e["status"]
        if e["newmode"] in ("120000", "160000") or (e["oldmode"] != "000000" and e["oldmode"][:2] != e["newmode"][:2] and status != "D"):
            problems.append(f"{path}: symlink/submodule/type change is not allowed")
            continue
        if matches_any(path, PROTECTED):
            problems.append(f"{path}: protected path ({status})")
            continue
        if not matches_any(path, ticket["allowed_paths"]):
            problems.append(f"{path}: outside allowed_paths ({status})")
            continue
        if path.startswith("tests/") and status in ("M", "D", "T"):
            problems.append(f"{path}: existing tests are append-only ({status})")
    if problems:
        return result("CHI-SCOPE", False, "; ".join(problems[:20]), violations=problems[:50])
    return result("CHI-SCOPE", True, f"{len(entries)} changed path(s), all within allowed_paths and unprotected")


def gate_mock(export: Path):
    hits = []
    for top in ("tests", "tools"):
        base = export / top
        if not base.is_dir():
            continue
        for f in sorted(base.rglob("*")):
            if not f.is_file() or "__pycache__" in f.parts:
                continue
            text = f.read_bytes().decode("utf-8", errors="replace")
            for n, line in enumerate(text.splitlines(), 1):
                m = MOCK_RE.search(line)
                if m:
                    hits.append(f"{f.relative_to(export)}:{n}: {m.group(0)}")
    if hits:
        return result("CHI-MOCK", False, "test-double machinery present: " + "; ".join(hits[:20]), matches=hits[:50])
    return result("CHI-MOCK", True, "no unittest.mock/Mock/MagicMock/patch/monkeypatch/mocker in tests/ or tools/")


def _is_trivial_assertion(call: ast.Call, name: str) -> bool:
    args = call.args

    def const(n):
        return isinstance(n, ast.Constant)

    if name in ("assertTrue",) and args:
        return const(args[0]) and bool(args[0].value)
    if name in ("assertFalse",) and args:
        return const(args[0]) and not args[0].value
    if name in ("assertIsNone",) and args:
        return const(args[0]) and args[0].value is None
    if name in ("assertIsNotNone",) and args:
        return const(args[0]) and args[0].value is not None
    if name in ("assertEqual", "assertIs", "assertCountEqual", "assertListEqual", "assertDictEqual", "assertMultiLineEqual") and len(args) >= 2:
        return ast.dump(args[0]) == ast.dump(args[1])
    if name in ("assertNotEqual", "assertIsNot") and len(args) >= 2:
        return const(args[0]) and const(args[1]) and args[0].value != args[1].value
    return False


def _direct_assertions(func) -> tuple[int, int]:
    """(real, trivial) assertion counts directly inside a function body."""
    real = trivial = 0
    for n in ast.walk(func):
        if isinstance(n, ast.Assert):
            t = n.test
            if isinstance(t, ast.Constant) and t.value or (
                isinstance(t, ast.Compare) and len(t.ops) == 1 and isinstance(t.ops[0], ast.Eq)
                and ast.dump(t.left) == ast.dump(t.comparators[0])
            ):
                trivial += 1
            else:
                real += 1
        elif isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr.startswith("assert"):
            if _is_trivial_assertion(n, n.func.attr):
                trivial += 1
            else:
                real += 1
    return real, trivial


def _skips(func) -> bool:
    for d in func.decorator_list:
        target = d.func if isinstance(d, ast.Call) else d
        nm = target.attr if isinstance(target, ast.Attribute) else getattr(target, "id", "")
        if nm.startswith("skip") or nm == "expectedFailure":
            return True
    return any(isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == "skipTest"
               for n in ast.walk(func))


def analyze_test_source(source: str):
    """Return (tests, error). tests: list of {qualname, real, trivial, skips, has_real}."""
    try:
        tree = ast.parse(source)
    except SyntaxError as exc:
        return [], f"syntax error: {exc}"
    funcs = {n.name: n for n in tree.body if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))}
    classes = {n.name: n for n in tree.body if isinstance(n, ast.ClassDef)}
    methods = {}
    for c in classes.values():
        for m in c.body:
            if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef)):
                methods[(c.name, m.name)] = m

    testcase_classes = set()
    changed = True
    while changed:
        changed = False
        for name, c in classes.items():
            if name in testcase_classes:
                continue
            for b in c.bases:
                bn = b.attr if isinstance(b, ast.Attribute) else getattr(b, "id", "")
                if bn.endswith("TestCase") or bn in testcase_classes:
                    testcase_classes.add(name)
                    changed = True
                    break

    # helpers that (transitively) contain a real assertion also count for callers
    helper_real = {m.name for (_, _), m in methods.items() if _direct_assertions(m)[0] > 0}
    helper_real |= {n for n, f in funcs.items() if _direct_assertions(f)[0] > 0}
    for _ in range(4):
        for (_, _), m in methods.items():
            if m.name in helper_real:
                continue
            calls = {n.func.attr for n in ast.walk(m) if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)}
            calls |= {n.func.id for n in ast.walk(m) if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)}
            if calls & helper_real:
                helper_real.add(m.name)

    tests = []
    for cname in sorted(testcase_classes):
        for (cn, mn), m in methods.items():
            if cn != cname or not mn.startswith("test"):
                continue
            real, trivial = _direct_assertions(m)
            calls = {n.func.attr for n in ast.walk(m) if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)}
            via_helper = bool((calls & helper_real) - {mn})
            tests.append({
                "qualname": f"{cn}.{mn}", "real": real, "trivial": trivial,
                "skips": _skips(m), "has_real": real > 0 or via_helper,
            })
    return tests, None


def added_test_files(entries):
    added = [e["path"] for e in entries if e["status"] == "A" and e["path"].endswith(".py")
             and Path(e["path"]).name.startswith("test")]
    return sorted(added)


def gate_assert(entries, export: Path, ticket):
    files = added_test_files(entries)
    if not files:
        return result("CHI-ASSERT", False, "no added test files (tests/test*.py) in the candidate diff", tests=[])
    problems, all_tests = [], []
    for f in files:
        p = Path(f)
        if p.parent.as_posix() != "tests":
            problems.append(f"{f}: not directly under tests/ (unittest discover -s tests would not run it)")
            continue
        tests, err = analyze_test_source((export / f).read_bytes().decode("utf-8", errors="replace"))
        if err:
            problems.append(f"{f}: {err}")
            continue
        for t in tests:
            t["file"] = f
            all_tests.append(t)
            if t["skips"]:
                problems.append(f"{f}::{t['qualname']}: skipped/expected-failure tests cannot count")
            elif not t["has_real"]:
                why = "only trivially-true assertions" if t["trivial"] else "no assertion"
                problems.append(f"{f}::{t['qualname']}: vacuous ({why})")
    counted = [t for t in all_tests if t["has_real"] and not t["skips"]]
    if len(counted) < ticket["min_new_tests"]:
        problems.append(f"only {len(counted)} non-vacuous new test(s); ticket requires {ticket['min_new_tests']}")
    if problems:
        return result("CHI-ASSERT", False, "; ".join(problems[:20]), new_tests=len(counted), tests=all_tests[:100])
    return result("CHI-ASSERT", True, f"{len(counted)} new non-vacuous test(s) in {len(files)} file(s)",
                  new_tests=len(counted), tests=all_tests[:100])


def run_tests(tree: Path, stems, env, timeout, tmp: Path, tag: str):
    """Run module stems under tests/ in tree with the in-process runner."""
    runner = tmp / "runner.py"
    if not runner.exists():
        runner.write_text(RUNNER)
    outfile = tmp / f"rows-{tag}.json"
    rc, out, err, ms, timed_out = run_cmd(
        [sys.executable, str(runner), str(outfile), *stems], tree, env, timeout)
    rows = []
    if outfile.exists():
        try:
            rows = json.loads(outfile.read_text())["rows"]
        except (ValueError, KeyError):
            rows = []
    return {"rc": rc, "rows": rows, "out": out, "err": err, "ms": ms, "timed_out": timed_out}


CRASH_MARKERS = ("_FailedTest", "ModuleImportFailure", "setUpClass", "setUpModule")


def _is_crash_row(row) -> bool:
    return any(m in row["id"] for m in CRASH_MARKERS)


def gate_canonical(export: Path, entries, ticket, env, timeout, tmp: Path, mdbook_out):
    steps_out, infra, failed = [], [], []
    py = sys.executable
    book = Path(mdbook_out) if mdbook_out else tmp / "book"
    steps = [
        ("verify", [py, "tools/verify.py", "--no-receipt"]),
        ("unittest", [py, "-m", "unittest", "discover", "-s", "tests", "-v"]),
        ("ggen-static", [py, "tools/verify_ggen_ecosystem.py"]),
        ("mdbook", ["mdbook", "build", "-d", str(book), "specification-guide"]),
        ("simulate", [py, "tools/simulate_fortune500.py", "examples/fortune500-fibo/enterprise.json"]),
    ]
    for name, cmd in steps:
        try:
            rc, out, err, ms, timed_out = run_cmd(cmd, export, env, timeout)
        except Infra as exc:
            infra.append(f"{name}: {exc}")
            steps_out.append({"step": name, "rc": None, "ms": 0, "infra": str(exc)})
            continue
        combined = out + err
        row = {"step": name, "rc": rc, "ms": ms, "tail": tail(combined, 600)}
        if timed_out:
            failed.append(f"{name}: timeout after {timeout}s")
            row["timeout"] = True
        elif rc != 0:
            if "ModuleNotFoundError" in combined or "No module named" in combined:
                infra.append(f"{name}: missing python dependency")
                row["infra"] = "missing python dependency"
            else:
                failed.append(f"{name}: exit {rc}")
        steps_out.append(row)

    # the new tests must actually run and pass (not skipped / filtered / crashed)
    files = [f for f in added_test_files(entries) if Path(f).parent.as_posix() == "tests"]
    stems = [Path(f).stem for f in files]
    expected = []
    for f in files:
        tests, _ = analyze_test_source((export / f).read_bytes().decode("utf-8", errors="replace"))
        expected += [f"{Path(f).stem}.{t['qualname']}" for t in tests if t["has_real"] and not t["skips"]]
    if stems:
        try:
            run = run_tests(export, stems, env, timeout, tmp, "canonical")
            ok_ids = {r["id"] for r in run["rows"] if r["outcome"] == "ok"}
            missing = [e for e in expected if e not in ok_ids]
            steps_out.append({"step": "new-tests", "rc": run["rc"], "ms": run["ms"], "ok": len(ok_ids), "expected": len(expected)})
            if missing or run["rc"] != 0:
                failed.append(f"new-tests: {len(missing)} expected test(s) did not pass, e.g. {missing[:3]}")
        except Infra as exc:
            infra.append(f"new-tests: {exc}")
    else:
        failed.append("new-tests: no added test modules to execute")

    if infra:
        return result("CHI-CANONICAL", False, "; ".join(infra), kind="infra", steps=steps_out)
    if failed:
        return result("CHI-CANONICAL", False, "; ".join(failed), steps=steps_out)
    return result("CHI-CANONICAL", True, "all canonical gates and the new tests passed", steps=steps_out)


# ---------------------------------------------------------------- mutation
def _pointer_get(doc, pointer: str):
    if pointer == "":
        return doc
    if not pointer.startswith("/"):
        raise ValueError(f"bad JSON pointer {pointer!r}")
    cur = doc
    for raw in pointer[1:].split("/"):
        key = raw.replace("~1", "/").replace("~0", "~")
        cur = cur[int(key)] if isinstance(cur, list) else cur[key]
    return cur


def apply_mutant(root: Path, mutant: dict) -> str:
    """Apply a mutant to root in place; return a human description. Raises ValueError if inapplicable."""
    kind = mutant["kind"]
    path = root / mutant["file"]
    doc = json.loads(path.read_text())
    obj = _pointer_get(doc, mutant.get("pointer", ""))
    if kind == "schema-drop-required":
        prop = mutant["property"]
        if prop not in obj.get("required", []):
            raise ValueError(f"{prop!r} is not in required at {mutant.get('pointer', '')!r}")
        obj["required"].remove(prop)
        desc = f"drop {prop!r} from required"
    elif kind == "schema-widen-additional":
        if obj.get("additionalProperties") is not False:
            raise ValueError("additionalProperties is not false at the pointer")
        obj["additionalProperties"] = True
        desc = "widen additionalProperties to true"
    elif kind == "schema-drop-enum-value":
        val = mutant["value"]
        if val not in obj.get("enum", []):
            raise ValueError(f"{val!r} is not in enum at {mutant.get('pointer', '')!r}")
        obj["enum"].remove(val)
        desc = f"drop {val!r} from enum"
    elif kind == "schema-drop-property":
        prop = mutant["property"]
        if prop not in obj.get("properties", {}):
            raise ValueError(f"{prop!r} is not a property at {mutant.get('pointer', '')!r}")
        del obj["properties"][prop]
        desc = f"delete property {prop!r}"
    else:
        raise KeyError(kind)
    path.write_text(json.dumps(doc, indent=2) + "\n")
    return desc


def gate_mutation(export: Path, entries, ticket, env, timeout, tmp: Path):
    files = [f for f in added_test_files(entries) if Path(f).parent.as_posix() == "tests"]
    stems = [Path(f).stem for f in files]
    mutants = ticket["mutants"]
    if not stems:
        return result("CHI-MUTATION", False, "no added test modules to mutation-check")
    if not mutants:
        return result("CHI-MUTATION", False, "ticket declares no mutants: non-vacuity cannot be evidenced")
    try:
        base = run_tests(export, stems, env, timeout, tmp, "baseline")
    except Infra as exc:
        return result("CHI-MUTATION", False, str(exc), kind="infra")
    if base["rc"] != 0 or not base["rows"] or any(r["outcome"] != "ok" for r in base["rows"]):
        bad = [r["id"] for r in base["rows"] if r["outcome"] != "ok"][:5]
        return result("CHI-MUTATION", False, f"unmutated head is not green for the new tests: {bad or 'crash'}")

    rows, problems, killed = [], [], 0
    for i, m in enumerate(mutants):
        copy = tmp / f"mut-{i}"
        shutil.copytree(export, copy)
        entry = {"id": m["id"], "kind": m["kind"]}
        try:
            entry["desc"] = apply_mutant(copy, m)
        except KeyError:
            entry["status"] = "unknown-kind"
            problems.append(f"{m['id']}: unknown mutant kind {m['kind']!r}")
            rows.append(entry)
            shutil.rmtree(copy, ignore_errors=True)
            continue
        except (ValueError, OSError) as exc:
            entry["status"] = "inapplicable"
            problems.append(f"{m['id']}: mutant not applicable: {exc}")
            rows.append(entry)
            shutil.rmtree(copy, ignore_errors=True)
            continue
        try:
            run = run_tests(copy, stems, env, timeout, tmp, f"mut-{i}")
        except Infra as exc:
            shutil.rmtree(copy, ignore_errors=True)
            return result("CHI-MUTATION", False, str(exc), kind="infra")
        failing = [r for r in run["rows"] if r["outcome"] in ("fail", "error") and not _is_crash_row(r)]
        if run["timed_out"]:
            entry["status"] = "error"
            problems.append(f"{m['id']}: timeout")
        elif run["rc"] == 0:
            entry["status"] = "survived"
            problems.append(f"{m['id']}: SURVIVED ({entry['desc']}); no new test detected the weakened schema")
        elif failing:
            entry["status"] = "killed"
            entry["killed_by"] = sorted({r["id"] for r in failing})[:5]
            killed += 1
        else:
            entry["status"] = "error"
            problems.append(f"{m['id']}: run crashed without a failing new test ({entry['desc']})")
        rows.append(entry)
        shutil.rmtree(copy, ignore_errors=True)
    ratio = killed / len(mutants)
    extra = {"kill_ratio": ratio, "killed": killed, "mutant_count": len(mutants), "mutants": rows}
    if ratio + 1e-9 < ticket["min_kill_ratio"] or problems:
        return result("CHI-MUTATION", False,
                      f"kill ratio {ratio:.2f} (need {ticket['min_kill_ratio']}); " + "; ".join(problems[:10]), **extra)
    return result("CHI-MUTATION", True, f"all {len(mutants)} mutant(s) killed by the new tests", **extra)


# ---------------------------------------------------------------- standing
def compute_standing(results):
    failed = [r for r in results if not r["pass"]]
    if not failed:
        return "ALIVE", 0
    if any(r["id"] in SAFETY_GATES and r["kind"] == "fail" for r in failed):
        return "REFUSED", 1
    if any(r["kind"] == "infra" for r in failed):
        return "BLOCKED", 2
    return "BLOCKED", 1


# ----------------------------------------------------------------- receipt
def build_receipt(args, ticket, results, standing, input_digest, timings):
    court_bytes = Path(__file__).read_bytes()
    gate_view = [{"id": r["id"], "pass": r["pass"], "kind": r["kind"]} for r in results]
    mut = next((r for r in results if r["id"] == "CHI-MUTATION"), {})
    asr = next((r for r in results if r["id"] == "CHI-ASSERT"), {})
    result_digest = sha256_hex(canonical({"gates": gate_view, "kill_ratio": mut.get("kill_ratio"),
                                          "new_tests": asr.get("new_tests")}))
    observation = {
        "court": COURT_VERSION,
        "gates": [{k: v for k, v in r.items() if k not in ("tests", "violations", "matches")} | {"ms": timings.get(r["id"], 0)}
                  for r in results],
        "failures": [{"id": r["id"], "kind": r["kind"]} for r in results if not r["pass"]],
        "killRatio": mut.get("kill_ratio"),
        "newTests": asr.get("new_tests"),
        "toolchain": toolchain(),
        "timingsMs": timings,
    }
    return {
        "receiptId": str(uuid.uuid4()),
        "sourceCoordinate": f"aps@{args.head}",
        "inputDigest": input_digest,
        "contractRef": f"aps-ticket:{ticket['item']}#{ticket['attempt']}" if ticket else "aps-ticket:unreadable#0",
        "executorRef": args.executor,
        "observation": observation,
        "resultDigest": result_digest,
        "standing": standing,
        "verifier": {"identity": args.verifier_identity,
                     "coordinate": f"{Path(__file__).name}@sha256:{sha256_hex(court_bytes)}"},
    }


def toolchain():
    def ver(cmd):
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout.strip()
            return out.splitlines()[0] if out else "unknown"
        except (OSError, subprocess.SubprocessError):
            return "unavailable"

    return {"python": sys.version.split()[0], "git": ver(["git", "--version"]), "mdbook": ver(["mdbook", "--version"])}


def validate_receipt(receipt, worktree: Path, base_sha, env):
    """Validate against the base tree's own schemas. Raises Infra if impossible or invalid."""
    import jsonschema
    from referencing import Registry, Resource

    def schema_text(name):
        for rev in [r for r in (base_sha, "HEAD") if r]:
            rc, out = git(worktree, "show", f"{rev}:contracts/{name}", env=env, check=False)
            if rc == 0:
                return out
        raise Infra(f"cannot read contracts/{name} from the base tree")

    schemas = {n: json.loads(schema_text(n)) for n in ("evidence-receipt.schema.json", "standing.schema.json")}
    registry = Registry().with_resources(
        [(s["$id"], Resource.from_contents(s)) for s in schemas.values()])
    validator = jsonschema.Draft202012Validator(schemas["evidence-receipt.schema.json"], registry=registry)
    errors = sorted(validator.iter_errors(receipt), key=lambda e: list(e.path))
    if errors:
        raise Infra("receipt does not validate against evidence-receipt.schema.json: "
                    + "; ".join(f"{list(e.path)}: {e.message}" for e in errors[:5]))


def emit(receipt, exit_code):
    print(json.dumps(receipt, sort_keys=True, separators=(",", ":")), flush=True)
    return exit_code


def emit_infra(args, why, ticket=None, base_sha=None, worktree=None, env=None):
    results = [result("CHI-TICKET" if ticket is None else "CHI-COURT", False, why, kind="infra")]
    log(f"[{results[0]['id']}] INFRA {why}")
    digest = sha256_hex(canonical({"head": args.head, "worktree": str(args.worktree), "why": why}))
    receipt = build_receipt(args, ticket, results, "BLOCKED", digest, {})
    if worktree is not None and env is not None:
        try:
            validate_receipt(receipt, Path(worktree), base_sha, env)
        except Exception as exc:  # best effort: an infra receipt may lack its schema source
            receipt["observation"]["receiptValidation"] = f"unvalidated: {exc}"[:300]
    return emit(receipt, 2)


# -------------------------------------------------------------------- main
def parse_args(argv):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--worktree", required=True)
    p.add_argument("--head", required=True, help="40-hex commit the worker claims as final head")
    p.add_argument("--ticket", required=True)
    p.add_argument("--executor", required=True)
    p.add_argument("--verifier-identity", required=True)
    p.add_argument("--mdbook-out", default=None)
    p.add_argument("--step-timeout", type=int, default=300)
    a = p.parse_args(argv)
    if not re.fullmatch(r"[0-9a-f]{40}", a.head):
        p.error("--head must be 40 lowercase hex characters")
    return a


def run_court(args, tmp: Path) -> int:
    wt = Path(args.worktree)
    home = tmp / "home"
    home.mkdir()
    env = child_env(home)

    if not wt.is_dir():
        return emit_infra(args, f"worktree does not exist: {wt}")
    try:
        ticket = load_ticket(args.ticket)
    except TicketError as exc:
        return emit_infra(args, str(exc), worktree=wt, env=env)
    base = ticket["base_sha"]

    if args.mdbook_out:
        out_dir = Path(args.mdbook_out).resolve()
        if out_dir == wt.resolve() or wt.resolve() in out_dir.parents:
            return emit_infra(args, "--mdbook-out must be outside the worktree", ticket, base, wt, env)

    timings, results = {}, {}

    def timed(gate_id, fn, *a):
        t = time.monotonic()
        res = fn(*a)
        timings[gate_id] = int((time.monotonic() - t) * 1000)
        results[gate_id] = res
        log(f"[{gate_id}] {'PASS' if res['pass'] else res['kind'].upper()} {tail(res['detail'], 300)}")
        return res

    # --- exact head (before)
    try:
        rc, actual = git(wt, "rev-parse", "HEAD", env=env)
        actual = actual.strip()
        has_head = git(wt, "cat-file", "-e", f"{args.head}^{{commit}}", env=env, check=False)[0] == 0
        has_base = git(wt, "cat-file", "-e", f"{base}^{{commit}}", env=env, check=False)[0] == 0
        ancestor = has_head and has_base and git(wt, "merge-base", "--is-ancestor", base, args.head, env=env, check=False)[0] == 0
        porcelain_before = git(wt, "status", "--porcelain", "--untracked-files=all", env=env)[1].strip()
    except Infra as exc:
        return emit_infra(args, f"cannot inspect worktree: {exc}", ticket, base, wt, env)

    checks = {"head_matches": actual == args.head, "head_exists": has_head, "base_ancestor_of_head": ancestor,
              "clean_before": porcelain_before == ""}
    head_ok = checks["head_matches"] and checks["head_exists"] and checks["base_ancestor_of_head"]

    timed("CHI-INDEPENDENT", gate_independent, args.executor, args.verifier_identity)

    entries, export = [], None
    if head_ok:
        try:
            export = tmp / "export"
            export_head(wt, args.head, export, env)
            entries = parse_raw_diff(wt, base, args.head, env)
        except Infra as exc:
            return emit_infra(args, f"cannot export head: {exc}", ticket, base, wt, env)
        timed("CHI-SCOPE", gate_scope, entries, ticket)
        timed("CHI-MOCK", gate_mock, export)
        timed("CHI-ASSERT", gate_assert, entries, export, ticket)
        timed("CHI-CANONICAL", gate_canonical, export, entries, ticket, env, args.step_timeout, tmp, args.mdbook_out)
        timed("CHI-MUTATION", gate_mutation, export, entries, ticket, env, args.step_timeout, tmp)
    else:
        why = "exact-head check failed"
        for gid in ("CHI-SCOPE", "CHI-MOCK", "CHI-ASSERT", "CHI-CANONICAL", "CHI-MUTATION"):
            results[gid] = skipped(gid, why)
            log(f"[{gid}] SKIPPED {why}")

    # --- exact head (after)
    try:
        after_head = git(wt, "rev-parse", "HEAD", env=env)[1].strip()
        porcelain_after = git(wt, "status", "--porcelain", "--untracked-files=all", env=env)[1].strip()
    except Infra as exc:
        return emit_infra(args, f"cannot re-inspect worktree: {exc}", ticket, base, wt, env)
    checks["clean_after"] = porcelain_after == ""
    checks["head_unchanged_after"] = after_head == actual
    bad = [k for k, v in checks.items() if not v]
    results["CHI-EXACT-HEAD"] = result(
        "CHI-EXACT-HEAD", not bad,
        "head, ancestry and cleanliness verified before and after" if not bad else
        f"failed checks: {bad}; claimed={args.head} actual={actual}" + (f"; dirty: {porcelain_before[:200]}" if not checks["clean_before"] else ""),
        checks=checks)
    log(f"[CHI-EXACT-HEAD] {'PASS' if not bad else 'FAIL ' + str(bad)}")

    ordered = [results[g] for g in ("CHI-EXACT-HEAD", "CHI-INDEPENDENT", "CHI-SCOPE", "CHI-MOCK",
                                    "CHI-ASSERT", "CHI-CANONICAL", "CHI-MUTATION")]
    standing, code = compute_standing(ordered)

    diff_bytes = git(wt, "diff", "--binary", "--no-renames", base, args.head, env=env, check=False, binary=True).stdout \
        if (has_head and has_base) else b""
    input_digest = sha256_hex(base.encode() + b"\n" + args.head.encode() + b"\n" + canonical(ticket) + b"\n" + diff_bytes)
    receipt = build_receipt(args, ticket, ordered, standing, input_digest, timings)
    try:
        validate_receipt(receipt, wt, base, env)
    except Exception as exc:
        log(f"[COURT] receipt invalid: {exc}")
        receipt["observation"]["receiptValidation"] = f"invalid: {exc}"[:300]
        return emit(receipt, 2)
    log(f"[COURT] standing {standing} exit {code}")
    return emit(receipt, code)


def main(argv=None) -> int:
    args = parse_args(argv)
    tmp = Path(tempfile.mkdtemp(prefix="aps-court-"))
    try:
        return run_court(args, tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
