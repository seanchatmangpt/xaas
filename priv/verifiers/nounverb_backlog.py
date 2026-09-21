#!/usr/bin/env python3
"""Deterministic work-item derivation for the ex_noun_verb_cli autonomic loop.

    python3 nounverb_backlog.py --repo PATH [--min-negatives 2] [--max-items 8]

Reads an ex_noun_verb_cli checkout (read-only) and prints ONE JSON document
{"schemaVersion": "nounverb-backlog/1", "head": ..., "items": [...]} sorted by
item id. The same repository state always yields byte-identical output: no
clocks, no randomness, no environment reads.

Fourth sibling of the Chicago-school public-surface family (`aps_backlog.py`
for schema contracts, `spr_backlog.py`/`eds_backlog.py` for Python tool
modules): this family derives negative-test items for the public functions of
the CLI's Elixir modules under lib/ex_noun_verb_cli. Elixir has no Python AST,
so the public surface is read with a documented LINE heuristic: a line that
matches `^\\s*def <name>(` (six public definition kinds: def, defp-less, so
NOT defp/defnp/defmacrop/defguardp/defoverridable) declares a public function.
It over-counts rather than under-counts (a `def` inside a quoted block would
only ADD candidate coverage), so an item is only emitted when coverage is
genuinely thin.

For each public function with fewer than --min-negatives negative fixtures in
test/, emit a work item asking for negative tests of that function (the
acceptance criterion the fabric verifier later enforces is the whole ExUnit
suite staying green at the worker's head).

Negative-fixture heuristic (documented, deliberately simple): a test
declaration counts as a negative fixture for function F when its enclosing
test block mentions F's name AND mentions an invalidity marker (assert_raise,
raise, {:error, invalid, reject, refus).
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

SCHEMA_VERSION = "nounverb-backlog/1"
LIB_DIR = "lib/ex_noun_verb_cli"
TEST_DIR = "test"
INVALID_MARKERS = ("assert_raise", "raise", "{:error", "invalid", "reject", "refus")
ID_PREFIX = "nounverb-neg"

# Public module-level definitions: `def name(` / `def name(` with no `p`
# suffix on the keyword. Explicitly excludes defp, defnp, defmacrop,
# defguardp, defoperatorp by requiring the keyword boundary.
_DEF_RE = re.compile(r"^\s*def\s+([a-z][A-Za-z0-9_?!]*)(\s*\(|\s+when\b|\s+do\b|$)")
_DEF_SHADOW_RE = re.compile(r"^\s*def(p|np|macrop|guardp|operatorp)\b")
_TEST_RE = re.compile(r'^\s*(?:test|describe)\s+"(.*)"')
_ID_SAFE = re.compile(r"[^a-z0-9_-]+")


def head_of(repo: Path) -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            timeout=20,
        )
        return out.stdout.strip() if out.returncode == 0 else "unknown"
    except (OSError, subprocess.SubprocessError):
        return "unknown"


def slugify(text: str) -> str:
    return _ID_SAFE.sub("-", text.lower()).strip("-")[:60]


def public_functions(module_path: Path) -> list[str]:
    """Public `def` names in source order, via the documented line heuristic.

    A `defp`-family line never emits a name (its own keyword matches the
    shadow regex first); a plain `def` line after it is still public, so
    scanning is line-local by construction.
    """
    names = []
    for line in module_path.read_text(errors="replace").splitlines():
        if _DEF_SHADOW_RE.match(line):
            continue
        m = _DEF_RE.match(line)
        if m and m.group(1) not in names:
            names.append(m.group(1))
    return names


def negative_blocks(tests_dir: Path) -> list[str]:
    """Source segments of every `test "..."` block under test/**/*_test.exs.

    A block runs from its `test "` line to the next `test "`/`describe "` line
    of ANY file (blocks are flattened across files -- a heuristic that can
    only over-count shared mentions, never under-count).
    """
    blocks = []
    for path in sorted(tests_dir.rglob("*_test.exs")):
        source = path.read_text(errors="replace")
        current = None
        for line in source.splitlines():
            if _TEST_RE.match(line):
                if current is not None:
                    blocks.append(current)
                current = line
            elif current is not None:
                current += "\n" + line
        if current is not None:
            blocks.append(current)
    return blocks


def negative_fixture_count(blocks: list[str], func: str) -> int:
    count = 0
    for segment in blocks:
        mentions = func in segment
        if mentions and any(m in segment for m in INVALID_MARKERS):
            count += 1
    return count


def build_item(stem: str, func: str, needed: int) -> dict:
    target = f"{stem}.{func}()"
    goal = (
        f"Add at least {needed} negative test(s) for {target} in the "
        f"ex_noun_verb_cli test suite under {TEST_DIR}/: each new test must "
        "call the function with an INVALID input (wrong shape, unknown key, "
        "malformed document, or content that violates the documented "
        "contract) and assert the documented failure mode (the raised "
        "exception, or the returned {:error, reason} tuple naming the "
        "failure). Follow the existing ExUnit style in test/. The ENTIRE "
        "suite must stay green: run `mix test` and keep it passing. Edit "
        f"ONLY files under {TEST_DIR}/. Commit with a clear message and "
        "close with your new head."
    )
    return {
        "id": f"{ID_PREFIX}-{slugify(stem)}-{slugify(func)}",
        "goal": goal,
        "allowed_paths": [TEST_DIR],
        "min_new_tests": needed,
        "min_kill_ratio": None,
        "mutants": [],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo", required=True, help="path to the ex_noun_verb_cli checkout (read-only)"
    )
    parser.add_argument("--min-negatives", type=int, default=2)
    parser.add_argument("--max-items", type=int, default=8)
    args = parser.parse_args()

    repo = Path(args.repo)
    lib = repo / LIB_DIR
    if not lib.is_dir():
        print(f"{LIB_DIR} not found under {repo}", file=sys.stderr)
        return 2

    blocks = negative_blocks(repo / TEST_DIR)
    items = []
    for module_path in sorted(lib.rglob("*.ex")):
        stem = module_path.stem
        for func in public_functions(module_path):
            have = negative_fixture_count(blocks, func)
            if have < args.min_negatives:
                items.append(build_item(stem, func, args.min_negatives - have))

    items.sort(key=lambda item: item["id"])
    items = items[: args.max_items]

    print(
        json.dumps(
            {
                "schemaVersion": SCHEMA_VERSION,
                "head": head_of(repo),
                "items": items,
                "mutants_bound": 0,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
