#!/usr/bin/env python3
"""Deterministic v26.9.23 Semantic Manufacturing release (the automation that executed the 2026-09-24 release:
xaas PR #65 -> main 5f408767, ggen_igniter PR #28 -> main fe92e611; state/receipts under $SJIRA_RELEASE_DIR) (operator 2026-09-23 22:05 PT: "finish all work then merge to the default
branches"; 22:55 PT: one canonical checkout per repository -> everything runs in ~/xaas and ~/ggen_igniter).

usage: release.py [--from STEP]      steps: pr, freeze, qualify, court, reseal, accept, merge, main, done

  pr       push friday/gc-fri-0800 -> release/v26.9.23, open/reuse the PR to main, wait for every check on the exact head;
           failures -> ZCode fix-forward in the int tree (<= 4 rounds, typed failure class), push, wait again
  freeze   S23 = (sha_xaas, sha_igniter, graph digest) -> release/FREEZE.json (previous freeze kept in history)
  qualify  full pinned gate at each frozen head IN the int tree -> receipts/fleet/<repo>-<sha>.json (fleet R schema)
  court    mix xaas.stop_court at the frozen pair -> release/int-stop-pre; expect GC23-0..11 ALIVE, GC23-12 on the operator edge
  reseal   court output byte-for-byte into docs/sjira/v26.9.23/receipts/ (receipts-only child commit), push, CI green again
  accept   stage operator/ACCEPTED.proposed + operator/ACCEPT-GC23-12.md (never ACCEPTED itself)
  merge    gh pr merge --merge --match-head-commit <green head>; verify second parent + origin/main
  main     fast-forward each int branch to origin/main, qualify at the main pair, stop court -> release/main-stop, release
           receipt, reproduce the court, tag v26.9.23 only if STOP=true
No LLM on any court or qualification path; ZCode is only the CI fix-forward constructor. State: release/release-state.json.
"""
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import threading
import time

SUB = os.environ.get("SJIRA_RELEASE_DIR", os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "sjira/release/v26.9.23"))
REL = f"{SUB}/release"
FLEET = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "sjira/receipts/fleet")
STATE = f"{REL}/release-state.json"
LOG = f"{REL}/release.log"
ZCODE = os.path.expanduser("~/dev/zcode-cli/bin/zcode.js")
DIGEST = "b1d3d24fc1937f48b2986b1b701409090d765d3d33c4ff75dc498558bb390dc1"
BR = "friday/gc-fri-0800"
LLM_ENV_PREFIXES = ("ANTHROPIC_", "CLAUDE_", "OPENAI_", "ZAI_", "Z_AI_", "GLM_", "ZCODE_")
R = {
    "xaas": {"int": os.environ.get("XAAS_DIR", os.path.expanduser("~/xaas")), "slug": "seanchatmangpt/xaas",
             "pin": "/Users/sac/.asdf/installs/elixir/1.20.2-otp-28/bin:/Users/sac/.asdf/installs/erlang/28.5.0.2/bin",
             "gate": [("format", "mix format --check-formatted"), ("compile", "MIX_ENV=test mix compile --force --warnings-as-errors"),
                      ("test", "mix test")]},
    "ggen_igniter": {"int": os.environ.get("GGEN_IGNITER_DIR", os.path.expanduser("~/ggen_igniter")), "slug": "seanchatmangpt/ggen_igniter",
                     "pin": "/Users/sac/.asdf/installs/elixir/1.18.4-otp-27/bin:/Users/sac/.asdf/installs/erlang/27.2.4/bin",
                     "gate": [("format", "mix format --check-formatted"), ("compile", "mix compile --warnings-as-errors --force"),
                              ("credo", "mix credo"), ("test", "mix test")]},
}
NAMES = ["xaas", "ggen_igniter"]
_lock = threading.Lock()


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def log(msg):
    with _lock:
        line = f"{now()} {msg}"
        print(line, flush=True)
        open(LOG, "a").write(line + "\n")


def sh(cmd, cwd=None, timeout=3600, env=None):
    p = subprocess.Popen(cmd, cwd=cwd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env,
                         start_new_session=True)
    try:
        out, err = p.communicate(timeout=timeout)
        return p.returncode, out, err
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, 9)
        out, err = p.communicate()
        return 124, out or "", (err or "") + f"\nTIMEOUT {timeout}s"


def pinned_env(n, extra=None):
    env = {k: v for k, v in os.environ.items() if not k.startswith(LLM_ENV_PREFIXES)}
    env["PATH"] = R[n]["pin"] + ":" + env["PATH"]
    if n == "xaas":
        env["GGEN_IGNITER_DIR"] = R["ggen_igniter"]["int"]
    env.update(extra or {})
    return env


def load_state():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(st):
    json.dump(st, open(STATE, "w"), indent=1)


def head(n):
    return sh(f"git -C {R[n]['int']} rev-parse HEAD")[1].strip()


class Lock:
    def __init__(self, n, owner):
        self.p, self.owner = f"{SUB}/locks/{n}.lock", owner
        os.makedirs(f"{SUB}/locks", exist_ok=True)

    def __enter__(self):
        while True:
            try:
                os.mkdir(self.p)
                break
            except FileExistsError:
                time.sleep(15)
        open(f"{self.p}/owner", "w").write(self.owner + "\n")

    def __exit__(self, *a):
        try:
            os.remove(f"{self.p}/owner")
        except FileNotFoundError:
            pass
        os.rmdir(self.p)


# ---------------------------------------------------------------- PR + CI

def ensure_pr(n):
    slug, intw = R[n]["slug"], R[n]["int"]
    rc, out, err = sh(f"git -C {intw} push origin {BR}:refs/heads/release/v26.9.23")
    if rc != 0:
        raise SystemExit(f"{n}: push release/v26.9.23 failed (never forcing): {err[-400:]}")
    rc, out, _ = sh(f"gh pr list -R {slug} --head release/v26.9.23 --state open --json number,url")
    prs = json.loads(out or "[]")
    if prs:
        return prs[0]["number"], prs[0]["url"]
    body = f"{REL}/pr-body-{n}.md"
    open(body, "w").write(
        f"# v26.9.23 semantic manufacturing reference loop (GC-26.9.23)\n\n"
        f"Release subject `{n}` branch `{BR}` (int checkout {intw}).\n\n"
        f"- Contract: operator PRD/ARD v26.9.23 (`docs/sjira/v26.9.23/prd-ard.md` in xaas); driver log "
        f"the single-repo migration record `~/.claude/migration/v26923-single-repo/` (lanes, courts, merges, migration ledger).\n"
        f"- Operator directive 2026-09-23 22:05 PT: finish all work, then merge to the default branches.\n"
        f"- Evidence: the pre-merge stop court (GC23-0..GC23-11 ALIVE expected; GC23-12 = operator acceptance pending) and the "
        f"exact-head qualification receipt are recorded out of tree and summarized in a PR comment before merge.\n"
        f"- GC23-12 acceptance is operator-only and is NOT part of this PR.\n"
        f"- No registry publish, no deploy, no tag.\n")
    rc, out, err = sh(f"gh pr create -R {slug} --base main --head release/v26.9.23 --title "
                      f"'v26.9.23 semantic manufacturing reference loop (GC-26.9.23)' --body-file {body}")
    if rc != 0:
        raise SystemExit(f"{n}: gh pr create failed: {err[-400:]}")
    url = out.strip().splitlines()[-1]
    return int(url.rstrip("/").split("/")[-1]), url


def wait_checks(n, pr, sha, max_wait=5 * 3600):
    """Poll the checks of the exact head sha; returns (ok, failing[list of dict])."""
    slug, t0 = R[n]["slug"], time.time()
    seen_any_at = None
    while time.time() - t0 < max_wait:
        rc, out, _ = sh(f"gh api 'repos/{slug}/commits/{sha}/check-runs?per_page=100' --jq '[.check_runs[] | "
                        f"{{name, status, conclusion, id: .id, url: .html_url, app: .app.slug}}]'")
        runs = json.loads(out or "[]") if rc == 0 else []
        if runs and seen_any_at is None:
            seen_any_at = time.time()
        pending = [r for r in runs if r["status"] != "completed"]
        if runs and not pending and time.time() - seen_any_at > 120:
            bad = [r for r in runs if r["conclusion"] not in ("success", "skipped", "neutral")]
            return (not bad), bad, runs
        if not runs and time.time() - t0 > 1200:
            return True, [], []  # no check runs for this head after 20 min: nothing gates it
        time.sleep(60)
    return False, [{"name": "TIMEOUT", "conclusion": "timed_out"}], []


def failed_logs(n, bad, dest):
    slug = R[n]["slug"]
    parts = []
    for b in bad[:6]:
        m = re.search(r"/runs/(\d+)", b.get("url") or "")
        if m:
            rc, out, err = sh(f"gh run view {m.group(1)} -R {slug} --log-failed", timeout=600)
            parts.append(f"### {b['name']} (run {m.group(1)}, {b['conclusion']})\n" + (out + err)[-12000:])
        else:
            parts.append(f"### {b['name']} ({b['conclusion']}) {b.get('url')}")
    open(dest, "w").write("\n\n".join(parts))
    return dest


def main_conclusion(n, name):
    slug = R[n]["slug"]
    rc, sha, _ = sh(f"gh api repos/{slug}/commits/main --jq .sha")
    rc, out, _ = sh(f"gh api 'repos/{slug}/commits/{sha.strip()}/check-runs?per_page=100' --jq "
                    f"'[.check_runs[] | select(.name == \"{name}\") | .conclusion] | first'")
    return out.strip().strip('"')


def zcode_fix(n, logs, rnd):
    intw = R[n]["int"]
    scratch = f"/private/tmp/claude-501/v23-scratch/REL-fix-{n}-r{rnd}"
    os.makedirs(scratch, exist_ok=True)
    prompt = f"""You are the fix-forward constructor for the v26.9.23 release PR of {n} (repo {R[n]['slug']}), working directly in the
canonical checkout {intw} on branch {BR} (the release runner is the only writer here). Exact-head CI failed.
Failing job logs: {logs}
Do: (1) diagnose each failure from the logs; (2) classify each as subject defect | environment | pre-existing (also failing on main) |
generator drift | evidence defect | infrastructure (generator-owned failures are fixed in the generator/template, not its output);
(3) fix forward with NEW commits on {BR} (git commit -F <file>; never rebase/reset/force/stash, no worktrees, no branches, no push -
the runner pushes); (4) rerun the relevant local tests under the pin (PATH={R[n]['pin']}:$PATH; check elixir --version);
(5) append one row per failure to {scratch}/CLASSIFICATION.md (check, class, cause, fix commit or reason not fixable here). Never skip,
weaken or delete a test to make CI green; a check that cannot pass for infrastructure reasons is recorded, not hidden. Doctrine:
~/.zcode/AGENTS.md. No git worktrees, no copies of the repository. Leave the tree clean. Finish with a summary of commits and commands."""
    pf = f"{scratch}/prompt.txt"
    open(pf, "w").write(prompt)
    rc, _, _ = sh(f"node {ZCODE} -p \"$(cat {pf})\" --cwd {intw} --mode yolo --json > {scratch}/zc.json 2> {scratch}/zc.err",
                  timeout=3 * 3600)
    if sh(f"git -C {intw} status --porcelain --untracked-files=no")[1].strip():
        sh(f"git -C {intw} add -u && git -C {intw} commit -q -m 'wip(release): fix-forward left uncommitted changes (round {rnd})'")
    log(f"{n}: zcode fix-forward round {rnd} => {rc}; classification {scratch}/CLASSIFICATION.md")
    return scratch


def step_pr(n, st, tag):
    pr, url = ensure_pr(n)
    st.setdefault("pr", {})[n] = {"number": pr, "url": url}
    for rnd in range(0, 5):
        h = head(n)
        sh(f"git -C {R[n]['int']} push origin {BR} {BR}:refs/heads/release/v26.9.23")
        log(f"{n}: [{tag}] waiting for checks at {h[:10]} (PR #{pr}, round {rnd})")
        ok, bad, runs = wait_checks(n, pr, h)
        st.setdefault("ci", {}).setdefault(n, []).append({"tag": tag, "sha": h, "ok": ok, "bad": bad, "runs": len(runs), "at": now()})
        if ok:
            log(f"{n}: [{tag}] checks green at {h[:10]} ({len(runs)} runs)")
            return h
        pre = [b for b in bad if main_conclusion(n, b["name"]) in ("failure", "cancelled", "timed_out")]
        log(f"{n}: [{tag}] failing {[b['name'] for b in bad]} (also failing on main: {[b['name'] for b in pre]})")
        if rnd == 4:
            break
        if len(pre) == len(bad) and rnd >= 2:
            st.setdefault("exempt", {})[n] = [{"check": b["name"], "class": "pre-existing", "evidence": "same check fails on main HEAD"}
                                             for b in pre]
            log(f"{n}: [{tag}] only pre-existing failures remain after 2 fix rounds: recorded as typed exemptions")
            return h
        with Lock(n, f"release:fix:{n}"):
            zcode_fix(n, failed_logs(n, bad, f"{REL}/ci-fail-{n}-{tag}-r{rnd}.log"), rnd)
    raise SystemExit(f"{n}: [{tag}] CI not green after 4 fix rounds; see {STATE}")


# ---------------------------------------------------------------- qualification + court

def qualify(n, st, stage):
    intw, sha = R[n]["int"], head(n)
    logs = f"{FLEET}/{n}-{sha}.logs"
    os.makedirs(logs, exist_ok=True)
    env = pinned_env(n)
    tool = sh("elixir --version", env=env)[1].strip().splitlines()
    cmds, observations, ok = [], [], True
    for i, (name, cmd) in enumerate(R[n]["gate"], 1):
        t0 = now()
        rc, out, err = sh(cmd, cwd=intw, env=env, timeout=4 * 3600)
        text = out + "\n--- stderr ---\n" + err
        lp = f"{logs}/{i:02d}-{name}.log"
        open(lp, "w").write(text)
        summ = [l for l in (out + err).splitlines() if re.search(r"tests?, \d+ failures?|Generated|found no issues|error", l)]
        cmds.append({"cmd": cmd, "cwd": intw, "exit": rc, "summary": ((summ[-1] if summ else "") + f" [{t0} -> {now()}]")[:400],
                     "output_sha256": hashlib.sha256(text.encode()).hexdigest(), "log": lp})
        log(f"{n}: qualify[{stage}] {name} => {rc}")
        dirty = sh(f"git -C {intw} status --porcelain --untracked-files=no")[1].strip()
        if dirty:  # a test rewrote a tracked file: keep the diff as evidence, restore the committed subject
            dp = f"{logs}/post-{name}.tracked.diff"
            open(dp, "w").write(sh(f"git -C {intw} diff")[1])
            sh(f"git -C {intw} checkout -- .")
            observations.append({"kind": "test_writes_tracked_file", "step": name, "files": dirty.splitlines()[:20], "evidence": dp,
                                 "disposition": "diff preserved, committed content restored (subject unchanged)"})
        if rc != 0:
            ok = False
            break
    rec = {
        "identity": {"subject": n, "repo": R[n]["slug"], "subject_sha": sha,
                     "base_sha": sh(f"git -C {intw} merge-base {sha} origin/main")[1].strip(), "branch": BR, "checkout": intw,
                     "frozen_by": f"{REL}/FREEZE.json", "stage": stage},
        "authority": {"ceiling": "OBSERVE", "grant": "release exact-head qualification (GC23-11); no commits, pushes, tags or PRs",
                      "actor": "lanes/release.py (deterministic, no LLM)"},
        "consequence": {"commits": [], "files_changed": [], "remote_effects": []},
        "replay": {"commands": cmds, "durable_location": logs},
        "toolchain": {"elixir": tool, "path_prefix": R[n]["pin"]},
        "observations": observations,
        "standing": {"value": "ALIVE" if ok else "BUILD_BROKEN",
                     "derived_from": f"{len(cmds)} gate step(s) at {sha}; ALIVE iff every step exited 0"},
    }
    if not ok:
        rec["standing"]["broken_term"] = "mu_unlawful"
    path = f"{FLEET}/{n}-{sha}.json"
    json.dump(rec, open(path, "w"), indent=1)
    vrc, vout, verr = sh(f"python3 ~/.claude/dfcm/validate_receipt.py {path}")
    log(f"{n}: qualification receipt {path} standing {rec['standing']['value']} validator => {vrc} {(vout + verr).strip()[-120:]}")
    st.setdefault("qualify", {}).setdefault(stage, {})[n] = {"sha": sha, "ok": ok, "receipt": path, "validator": vrc}
    return ok and vrc == 0


def court(dest, st, key):
    env = pinned_env("xaas", {"MIX_ENV": "test", "GC23_FLEET_RECEIPTS_DIR": FLEET})
    os.makedirs(dest, exist_ok=True)
    rc, out, err = sh(f"timeout 3000 mix xaas.stop_court --checkpoint GC-26.9.23 --receipts-dir {dest}", cwd=R["xaas"]["int"],
                      env=env, timeout=3300)
    open(f"{dest}/court.out.log", "w").write(out + "\n--- stderr ---\n" + err)
    gates = {}
    for i in range(13):
        p = f"{dest}/GC23-{i}.json"
        if os.path.exists(p):
            d = json.load(open(p))
            gates[f"GC23-{i}"] = {"standing": d["standing"]["value"], "why": d["standing"].get("derived_from", "")[:200],
                                  "last": (d.get("replay", {}).get("commands") or [{}])[-1].get("summary", "")[:200]}
    stop = json.load(open(f"{dest}/STOP-GC-26.9.23.json")) if os.path.exists(f"{dest}/STOP-GC-26.9.23.json") else {}
    val = [sh(f"python3 ~/.claude/dfcm/validate_receipt.py {dest}/{f}")[0] for f in sorted(os.listdir(dest)) if f.endswith(".json")]
    res = {"exit": rc, "gates": gates, "stop": stop.get("standing", {}), "validators_nonzero": sum(1 for v in val if v),
           "xaas": head("xaas"), "ggen_igniter": head("ggen_igniter")}
    st.setdefault("court", {})[key] = res
    alive = sorted(g for g, v in gates.items() if v["standing"] == "ALIVE")
    log(f"court[{key}] exit {rc}: ALIVE {len(alive)}/13; non-ALIVE: {[(g, v['standing'], v['last'][:80]) for g, v in gates.items() if v['standing'] != 'ALIVE']}")
    return res


def pre_acceptance_ok(res):
    g = res["gates"]
    return all(g.get(f"GC23-{i}", {}).get("standing") == "ALIVE" for i in range(12)) and g.get("GC23-12", {}).get("standing") != "ALIVE"


# ---------------------------------------------------------------- main

def par(fn):
    out, errs = {}, {}

    def run(n):
        try:
            out[n] = fn(n)
        except BaseException as e:  # typed: surfaced below, the other repo keeps running
            errs[n] = repr(e)
    ts = [threading.Thread(target=run, args=(n,)) for n in NAMES]
    [t.start() for t in ts]
    [t.join() for t in ts]
    if errs:
        raise SystemExit(f"parallel step failed: {errs}")
    return out


def main():
    steps = ["pr", "freeze", "qualify", "court", "reseal", "accept", "merge", "main", "done"]
    start = sys.argv[sys.argv.index("--from") + 1] if "--from" in sys.argv else load_state().get("next", "pr")
    st = load_state()
    for step in steps[steps.index(start):]:
        st["next"] = step
        save_state(st)
        log(f"== step {step}")
        if step == "pr":
            st["green"] = par(lambda n: step_pr(n, st, "pre-freeze"))
        elif step == "freeze":
            old = json.load(open(f"{REL}/FREEZE.json")) if os.path.exists(f"{REL}/FREEZE.json") else None
            for n in NAMES:
                if sh(f"git -C {R[n]['int']} status --porcelain --untracked-files=no")[1].strip():
                    raise SystemExit(f"freeze: {n} int tree has tracked changes")
                if os.path.exists(f"{R[n]['int']}.merge.lock"):
                    raise SystemExit(f"freeze: {n} merge lock held")
            gd = hashlib.sha256(open(f"{R['xaas']['int']}/docs/sjira/v26.9.23/goal.ttl", "rb").read()).hexdigest()
            fr = {n: {"sha": head(n), "branch": BR} for n in NAMES}
            fr.update(graph_digest=f"sha256:{gd}", recorded_at=now(), recorded_by="lanes/release.py",
                      history=((old or {}).get("history", []) + ([{k: v for k, v in old.items() if k != "history"}] if old else [])))
            json.dump(fr, open(f"{REL}/FREEZE.json", "w"), indent=1)
            st["freeze"] = {n: fr[n]["sha"] for n in NAMES}
            log(f"freeze S23 = {st['freeze']} graph sha256:{gd[:16]}")
        elif step == "qualify":
            res = par(lambda n: qualify(n, st, "int"))
            if not all(res.values()):
                raise SystemExit(f"qualification failed: {res}")
        elif step == "court":
            res = court(f"{REL}/int-stop-pre", st, "int")
            if not pre_acceptance_ok(res):
                raise SystemExit("int court is not in the pre-acceptance state (GC23-0..11 ALIVE, GC23-12 open): release defect")
        elif step == "reseal":
            x = R["xaas"]["int"]
            with Lock("xaas", "release:reseal"):
                dst = f"{x}/docs/sjira/v26.9.23/receipts"
                src = f"{REL}/int-stop-pre"
                for f in sorted(os.listdir(src)):
                    if f.endswith(".json"):
                        sh(f"cp {src}/{f} {dst}/{f}")
                bad = [f for f in os.listdir(src) if f.endswith(".json") and sh(f"cmp -s {src}/{f} {dst}/{f}")[0] != 0]
                if bad:
                    raise SystemExit(f"reseal cmp mismatch: {bad}")
                g = st["court"]["int"]["gates"]
                msg = f"{REL}/reseal.msg"
                open(msg, "w").write(
                    f"receipts(v26.9.23): reseal GC-26.9.23 evidence from the owning stop court at the frozen subject\n\n"
                    f"Binds xaas {st['freeze']['xaas']} + ggen_igniter {st['freeze']['ggen_igniter']} (release/FREEZE.json);\n"
                    f"this commit is its child and changes only docs/sjira/v26.9.23/receipts/ (court output copied byte for byte).\n\n"
                    + "\n".join(f"{k} {v['standing']}" for k, v in sorted(g.items(), key=lambda kv: int(kv[0].split('-')[1])))
                    + "\nSTOP=false (pre-acceptance: GC23-12 waits on the operator's ACCEPTED).\n")
                sh(f"git -C {x} add docs/sjira/v26.9.23/receipts/")
                changed = sh(f"git -C {x} diff --cached --name-only")[1].split()
                if any(not c.startswith("docs/sjira/v26.9.23/receipts/") for c in changed):
                    raise SystemExit(f"reseal would commit outside the receipts dir: {changed}")
                if changed:
                    rc, _, err = sh(f"git -C {x} commit -q -F {msg}")
                    if rc:
                        raise SystemExit(f"reseal commit failed: {err}")
            log(f"reseal committed {head('xaas')[:10]} ({len(changed)} receipt files)")
            st["green"]["xaas"] = step_pr("xaas", st, "post-reseal")
        elif step == "accept":
            x = R["xaas"]["int"]
            got = hashlib.sha256(subprocess.run(["git", "-C", x, "show", "HEAD:docs/sjira/v26.9.23/successor/v26.9.24-wbpr.md"],
                                                capture_output=True).stdout).hexdigest()
            if got != DIGEST:
                raise SystemExit(f"successor digest mismatch: {got}")
            os.makedirs(f"{SUB}/operator", exist_ok=True)
            open(f"{SUB}/operator/ACCEPTED.proposed", "w").write(f"sha256:{DIGEST}\n")
            open(f"{SUB}/operator/ACCEPT-GC23-12.md", "w").write(f"""# GC23-12 acceptance (operator action)

Staged by lanes/release.py at {now()}. Acceptance cannot come from the conversation, a plan, or an agent: only the operator creates
`docs/sjira/v26.9.23/successor/ACCEPTED`.

What is accepted: `docs/sjira/v26.9.23/successor/v26.9.24-wbpr.md` in xaas (the successor prose V23-H manufactured through the
v26.9.23 first-mile pipeline), sha256 `{DIGEST}`.

After the release PRs merge (xaas main contains the release):

```bash
cd ~/xaas && git switch main && git pull --ff-only
git show HEAD:docs/sjira/v26.9.23/successor/v26.9.24-wbpr.md | shasum -a 256   # must print {DIGEST}
cp ~/.claude/migration/v26923-single-repo/operator/ACCEPTED.proposed docs/sjira/v26.9.23/successor/ACCEPTED
git add docs/sjira/v26.9.23/successor/ACCEPTED && git commit -m "accept(v26.9.23): GC23-12 successor prose sha256:{DIGEST[:12]}"
git push origin main
```

Then the driver reruns the stop court at the main pair (13/13, STOP=true expected), reseals, and runs the Chatman root crown and the
v26.9.23 tags (tag last).
""")
            log("acceptance staged: operator/ACCEPTED.proposed + operator/ACCEPT-GC23-12.md")
        elif step == "merge":
            for n in NAMES:
                pr, h = st["pr"][n]["number"], head(n)
                if h != st["green"][n]:
                    raise SystemExit(f"{n}: head {h} moved past the green head {st['green'][n]}")
                rc, out, err = sh(f"gh pr merge {pr} -R {R[n]['slug']} --merge --match-head-commit {h}")
                if rc:
                    raise SystemExit(f"{n}: merge failed: {err[-400:]}")
                sh(f"git -C {R[n]['int']} fetch origin --no-prune")
                m = sh(f"git -C {R[n]['int']} rev-parse origin/main")[1].strip()
                p2 = sh(f"git -C {R[n]['int']} rev-parse origin/main^2")[1].strip()
                if p2 != h:
                    raise SystemExit(f"{n}: origin/main {m} second parent {p2} != green head {h}")
                st.setdefault("merged", {})[n] = {"merge_sha": m, "head": h}
                log(f"{n}: merged PR #{pr} -> main {m[:10]} (second parent {h[:10]})")
        elif step == "main":
            for n in NAMES:
                with Lock(n, "release:rebind"):
                    sh(f"git -C {R[n]['int']} fetch origin --no-prune")
                    rc, _, err = sh(f"git -C {R[n]['int']} switch main && git -C {R[n]['int']} merge --ff-only origin/main")
                    if rc:
                        raise SystemExit(f"{n}: update canonical main failed: {err}")
                log(f"{n}: canonical checkout on main {head(n)[:10]} (contains merge {st['merged'][n]['merge_sha'][:10]})")
            res = par(lambda n: qualify(n, st, "main"))
            if not all(res.values()):
                raise SystemExit(f"main qualification failed: {res}")
            cm = court(f"{REL}/main-stop", st, "main")
            cv = court("/private/tmp/claude-501/v23-scratch/REL-verify", st, "reproduce")
            same = {g: v["standing"] for g, v in cm["gates"].items()} == {g: v["standing"] for g, v in cv["gates"].items()}
            stop_true = cm["exit"] == 0 and all(v["standing"] == "ALIVE" for v in cm["gates"].values()) and len(cm["gates"]) == 13
            h = lambda p: "sha256:" + hashlib.sha256(open(p, "rb").read()).hexdigest()
            gi = R["ggen_igniter"]["int"]
            rr = {
                "identity": {"subject": "GC-26.9.23/release", "subject_sha": head("xaas"), "repo": "seanchatmangpt/xaas",
                             "base_sha": sh(f"git -C {R['xaas']['int']} rev-parse {head('xaas')}^1")[1].strip(),
                             "main_pair": {n: head(n) for n in NAMES}, "frozen_int_pair": st["freeze"],
                             "graph_hash": h(f"{R['xaas']['int']}/docs/sjira/v26.9.23/goal.ttl")},
                "authority": {"ceiling": "OBSERVE", "grant": "operator directive 2026-09-23 22:05 PT (merge to default branches)",
                              "actor": "lanes/release.py (deterministic)"},
                "consequence": {"commits": [], "files_changed": [], "remote_effects": [
                    f"{R[n]['slug']} PR #{st['pr'][n]['number']} merged -> {st['merged'][n]['merge_sha']}" for n in NAMES]},
                "replay": {"commands": [{"cmd": "mix xaas.stop_court --checkpoint GC-26.9.23 --receipts-dir <dir>",
                                         "cwd": R["xaas"]["int"], "exit": cm["exit"], "summary": json.dumps(cm["stop"])[:300]}],
                           "reproduced": same},
                "release": {
                    "checkpoint": "GC-26.9.23",
                    "ontology_digest": h(f"{gi}/priv/ggen/semantic-jira-pack/ontology.ttl") if os.path.exists(f"{gi}/priv/ggen/semantic-jira-pack/ontology.ttl") else None,
                    "receipt_schema_digest": h(os.path.expanduser("~/.claude/dfcm/receipt.schema.json")),
                    "qualification": st["qualify"].get("main"), "gate_receipts": {g: h(f"{REL}/main-stop/{g}.json") for g in cm["gates"]},
                    "stop_receipt": h(f"{REL}/main-stop/STOP-GC-26.9.23.json") if os.path.exists(f"{REL}/main-stop/STOP-GC-26.9.23.json") else None,
                    "STOP": stop_true,
                    "open_edges": [{"gate": g, "standing": v["standing"], "edge": "operator acceptance" if g == "GC23-12" else v["last"]}
                                   for g, v in cm["gates"].items() if v["standing"] != "ALIVE"],
                    "ci_exemptions": st.get("exempt", {}),
                },
                "standing": {"value": "ALIVE" if stop_true and same else "PARTIAL_ALIVE",
                             "derived_from": f"main-pair stop court: {sum(1 for v in cm['gates'].values() if v['standing'] == 'ALIVE')}/13 ALIVE, "
                                             f"STOP={stop_true}, reproduced={same}"},
            }
            json.dump(rr, open(f"{REL}/release-receipt.json", "w"), indent=1)
            vrc = sh(f"python3 ~/.claude/dfcm/validate_receipt.py {REL}/release-receipt.json")[0]
            log(f"release receipt {REL}/release-receipt.json standing {rr['standing']['value']} validator {vrc}")
            log("no tag here: all v26.9.23 tags are created together at CE-REL after the Chatman root crown (DRIVER tag scope)"
                + ("; STOP=true reproduced" if stop_true and same else "; STOP is not true at the main pair"))
        elif step == "done":
            log("release.py done")
        save_state(st)
    st["next"] = "done"
    save_state(st)


if __name__ == "__main__":
    main()
