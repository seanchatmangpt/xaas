#!/usr/bin/env python3
"""Deterministic work-item derivation for the SPR autonomic loop (a "sense" stage).

    python3 spr_backlog.py --repo PATH [--min-negatives 2] [--max-items 8]

Reads an SPR checkout (read-only) and prints ONE JSON document
{"schemaVersion": "spr-backlog/1", "head": ..., "items": [...]} sorted by item
id. The same repository state always yields byte-identical output: no clocks,
no randomness, no environment reads.

This is the sibling of `aps_backlog.py` for a different repo family: where the
APS family derives Chicago-school tests for `contracts/*.schema.json` files,
the SPR family derives them for the public functions of the repo's root tool
module (`sprtool.py`): for each public module-level function with fewer than
--min-negatives negative fixtures in tests/, emit a work item asking for
negative tests of that function (the acceptance criterion the fabric verifier
later enforces is the whole suite staying green at the worker's head).

Negative-fixture heuristic (documented, deliberately simple): a `test`
function or TestCase method counts as a negative fixture for function F when
its source mentions F's name AND mentions an invalidity marker
(assertRaises, pytest.raises, raises=, SprError, ValueError, TypeError,
invalid, reject, refus, violations). It over-counts rather than
under-counts, so an item is only emitted when coverage is genuinely thin.
"""
from __future__ import annotations

import argparse
import ast
import json
import subprocess
import sys
from pathlib import Path

SCHEMA_VERSION = "spr-backlog/1"
TOOL_MODULE = "sprtool.py"
INVALID_MARKERS = (
    "assertRaises",
    "pytest.raises",
    "raises=",
    "SprError",
    "ValueError",
    "TypeError",
    "invalid",
    "reject",
    "refus",
    "violations",
)
MAX_MUTANTS = 0  # SPR items carry no mutation spec; the suite is the court.


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


def public_functions(module_path: Path) -> list[str]:
    """Module-level `def` names without a leading underscore, in source order."""
    tree = ast.parse(module_path.read_text(errors="replace"))
    names = []
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if not node.name.startswith("_"):
                names.append(node.name)
    return names


def iter_test_nodes(tests_dir: Path):
    """Yield (name, source_segment) for every test function / TestCase method."""
    if not tests_dir.is_dir():
        return
    for path in sorted(tests_dir.glob("*.py")):
        source = path.read_text(errors="replace")
        try:
            tree = ast.parse(source)
        except SyntaxError:
            continue
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                name = node.name
                if not name.startswith("test"):
                    continue
                seg = ast.get_source_segment(source, node) or ""
                yield f"{path.name}:{name}", seg


def negative_fixture_count(tests_dir: Path, func: str) -> int:
    count = 0
    for _key, segment in iter_test_nodes(tests_dir):
        mentions = func in segment
        if mentions and any(m in segment for m in INVALID_MARKERS):
            count += 1
    return count


def build_item(func: str, needed: int) -> dict:
    goal = (
        f"Add at least {needed} negative test(s) for sprtool.{func}() in "
        f"tests/test_sprtool.py: each new test must call sprtool.{func} with an "
        "INVALID input (wrong type, malformed document, unreadable path, or "
        "content that violates the documented contract) and assert the "
        "documented failure mode (SprError raised, or the returned violation "
        "list naming the violation). Follow the existing unittest style in "
        "tests/test_sprtool.py. The ENTIRE suite must stay green: run "
        "`python3 -m pytest tests -q` and keep it passing. Edit ONLY "
        "tests/test_sprtool.py. Commit with a clear message and close with "
        "your new head."
    )
    return {
        "id": f"spr-neg-{func}",
        "goal": goal,
        "allowed_paths": ["tests/test_sprtool.py"],
        "min_new_tests": needed,
        "min_kill_ratio": None,
        "mutants": [],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="path to the SPR checkout (read-only)")
    parser.add_argument("--min-negatives", type=int, default=2)
    parser.add_argument("--max-items", type=int, default=8)
    args = parser.parse_args()

    repo = Path(args.repo)
    module = repo / TOOL_MODULE
    if not module.is_file():
        print(f"{TOOL_MODULE} not found under {repo}", file=sys.stderr)
        return 2

    tests_dir = repo / "tests"
    items = []
    for func in public_functions(module):
        have = negative_fixture_count(tests_dir, func)
        if have < args.min_negatives:
            items.append(build_item(func, args.min_negatives - have))

    items.sort(key=lambda item: item["id"])
    items = items[: args.max_items]

    print(
        json.dumps(
            {
                "schemaVersion": SCHEMA_VERSION,
                "head": head_of(repo),
                "items": items,
                "mutants_bound": MAX_MUTANTS,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
