#!/usr/bin/env python3
"""Deterministic work-item derivation for the EDS autonomic loop (a "sense" stage).

    python3 eds_backlog.py --repo PATH [--min-negatives 2] [--max-items 8]

Reads an EDS checkout (read-only) and prints ONE JSON document
{"schemaVersion": "eds-backlog/1", "head": ..., "items": [...]} sorted by item
id. The same repository state always yields byte-identical output: no clocks,
no randomness, no environment reads.

This is the third sibling of the Chicago-school public-surface family
(`aps_backlog.py` for schema contracts, `spr_backlog.py` for a root tool
module): where those families derive negative tests for one file, the EDS
family derives them for the public module-level functions of EVERY module in
the `src/eds/` package. For each public function with fewer than
--min-negatives negative fixtures in tests/, emit a work item asking for
negative tests of that function (the acceptance criterion the fabric verifier
later enforces is the whole pytest suite staying green at the worker's head).

Negative-fixture heuristic (documented, deliberately simple): a `test`
function counts as a negative fixture for function F when its source mentions
F's name AND mentions an invalidity marker (pytest.raises, assertRaises,
raises=, Error, invalid, reject, refus, violations). It over-counts rather
than under-counts, so an item is only emitted when coverage is genuinely thin.
"""
from __future__ import annotations

import argparse
import ast
import json
import re
import subprocess
import sys
from pathlib import Path

SCHEMA_VERSION = "eds-backlog/1"
PACKAGE_DIR = "src/eds"
INVALID_MARKERS = (
    "pytest.raises",
    "assertRaises",
    "raises=",
    "Error",
    "invalid",
    "reject",
    "refus",
    "violations",
)
ID_PREFIX = "eds-neg"
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
    """Module-level `def` names without a leading underscore, in source order."""
    try:
        tree = ast.parse(module_path.read_text(errors="replace"))
    except SyntaxError:
        return []

    names = []
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if not node.name.startswith("_"):
                names.append(node.name)
    return names


def iter_test_nodes(tests_dir: Path):
    """Yield (key, source_segment) for every test function in tests/*.py."""
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


def build_item(stem: str, func: str, needed: int) -> dict:
    target = f"eds.{stem}.{func}()"
    goal = (
        f"Add at least {needed} negative test(s) for {target} in the eds test "
        f"suite under tests/: each new test must call {target} with an INVALID "
        "input (wrong type, malformed document, unknown identifier, or content "
        "that violates the documented contract) and assert the documented "
        "failure mode (the raised exception class, or the returned violation/"
        "error value naming the violation). Follow the existing pytest style in "
        "tests/. The ENTIRE suite must stay green: run "
        "`python3 -m pytest tests -q` and keep it passing. Edit ONLY files "
        "under tests/. Commit with a clear message and close with your new head."
    )
    return {
        "id": f"{ID_PREFIX}-{slugify(stem)}-{slugify(func)}",
        "goal": goal,
        "allowed_paths": ["tests"],
        "min_new_tests": needed,
        "min_kill_ratio": None,
        "mutants": [],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="path to the EDS checkout (read-only)")
    parser.add_argument("--min-negatives", type=int, default=2)
    parser.add_argument("--max-items", type=int, default=8)
    args = parser.parse_args()

    repo = Path(args.repo)
    package = repo / PACKAGE_DIR
    if not package.is_dir():
        print(f"{PACKAGE_DIR} not found under {repo}", file=sys.stderr)
        return 2

    tests_dir = repo / "tests"
    items = []
    for module_path in sorted(package.glob("*.py")):
        stem = module_path.stem
        if stem == "__init__":
            continue
        for func in public_functions(module_path):
            have = negative_fixture_count(tests_dir, func)
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
