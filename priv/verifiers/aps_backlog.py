#!/usr/bin/env python3
"""Deterministic work-item derivation for the APS autonomic loop (the "sense" stage).

    python3 aps_backlog.py --repo PATH [--min-negatives 3]

Reads an APS checkout (read-only) and prints ONE JSON document
{"schemaVersion": "aps-backlog/1", "head": ..., "items": [...]} sorted by item
id. The same repository state always yields byte-identical output: no clocks,
no randomness, no environment reads.

Item family: for each contracts/*.schema.json that has fewer than
--min-negatives negative fixtures in tests/, emit a work item asking for
Chicago-school tests of that schema, with mutants derived from the schema
itself (the acceptance criterion the court later enforces).

Negative-fixture heuristic (documented, deliberately simple): a `test*`
function counts as a negative fixture for schema S when its source mentions
S's file name or a quoted stem AND mentions an invalidity marker
(ValidationError, assertRaises, is_valid, iter_errors, invalid, reject,
refus). It over-counts rather than under-counts, so an item is only emitted
when coverage is genuinely thin.
"""
from __future__ import annotations

import argparse
import ast
import json
import subprocess
import sys
from pathlib import Path

SCHEMA_VERSION = "aps-backlog/1"
INVALID_MARKERS = ("ValidationError", "assertRaises", "is_valid", "iter_errors", "invalid", "reject", "refus")
MAX_REQUIRED_MUTANTS = 4
MAX_ENUM_MUTANTS = 2


def head_of(repo: Path) -> str:
    try:
        out = subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"], capture_output=True, text=True, timeout=20)
        return out.stdout.strip() if out.returncode == 0 else "unknown"
    except (OSError, subprocess.SubprocessError):
        return "unknown"


def negative_fixture_count(tests_dir: Path, stem: str) -> int:
    count = 0
    file_name = f"{stem}.schema.json"
    quoted = (f'"{stem}"', f"'{stem}'")
    if not tests_dir.is_dir():
        return 0
    for path in sorted(tests_dir.glob("*.py")):
        source = path.read_text(errors="replace")
        try:
            tree = ast.parse(source)
        except SyntaxError:
            continue
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith("test"):
                text = ast.get_source_segment(source, node) or ""
                mentions = file_name in text or any(q in text for q in quoted)
                if mentions and any(m in text for m in INVALID_MARKERS):
                    count += 1
    return count


def walk_enums(node, pointer=""):
    """Yield (pointer_to_object_holding_enum, enum_list) in document order."""
    if isinstance(node, dict):
        if isinstance(node.get("enum"), list):
            yield pointer, node["enum"]
        for key, value in node.items():
            child = pointer + "/" + str(key).replace("~", "~0").replace("/", "~1")
            yield from walk_enums(value, child)
    elif isinstance(node, list):
        for i, value in enumerate(node):
            yield from walk_enums(value, f"{pointer}/{i}")


def derive_mutants(stem: str, rel_file: str, schema: dict) -> list[dict]:
    mutants = []
    for prop in list(schema.get("required", []))[:MAX_REQUIRED_MUTANTS]:
        mutants.append({"id": f"{stem}:drop-required:{prop}", "kind": "schema-drop-required",
                        "file": rel_file, "pointer": "", "property": prop})
    if schema.get("additionalProperties") is False:
        mutants.append({"id": f"{stem}:widen-additional", "kind": "schema-widen-additional",
                        "file": rel_file, "pointer": ""})
    for pointer, values in list(walk_enums(schema))[:MAX_ENUM_MUTANTS]:
        if not values:
            continue
        mutants.append({"id": f"{stem}:drop-enum:{pointer or 'root'}:{values[0]}", "kind": "schema-drop-enum-value",
                        "file": rel_file, "pointer": pointer, "value": values[0]})
    return mutants


def describe(m: dict) -> str:
    where = f" at pointer {m['pointer']!r}" if m.get("pointer") else " at the schema root"
    if m["kind"] == "schema-drop-required":
        return f"`{m['property']}` removed from `required`{where}"
    if m["kind"] == "schema-widen-additional":
        return f"`additionalProperties` changed from false to true{where}"
    return f"the enum member {m['value']!r} removed{where}"


def build_goal(stem: str, rel_file: str, mutants: list[dict]) -> str:
    us = stem.replace("-", "_")
    test_file = f"tests/test_contract_{us}.py"
    weakened = "\n".join(f"  - {describe(m)}" for m in mutants)
    return (
        f"Create exactly one new file, {test_file}, containing Chicago-school unit tests for the JSON Schema "
        f"{rel_file}, then `git add {test_file}` and `git commit -m \"test(contract): {stem}\"`. "
        "Touch no other file. You cannot run Python or tests in this session, so write plain, conservative code.\n\n"
        "Rules (an independent court enforces every one; a violation is rejected and you are asked to repair):\n"
        "  1. Use only `unittest` and `jsonschema` (Draft202012Validator) against the REAL schema file, loaded from "
        f"`pathlib.Path(__file__).resolve().parents[1] / \"contracts\" / \"{stem}.schema.json\"`. If the schema has a "
        "relative `$ref` to another file in contracts/, build a `referencing.Registry` from every contracts/*.schema.json "
        "keyed by its `$id` so the ref resolves.\n"
        "  2. Write at least 4 test methods in a `unittest.TestCase` subclass: at least 3 negative fixtures, each violating a "
        "different constraint (assert the validator reports an error, e.g. `assertFalse(validator.is_valid(x))` or "
        "`assertRaises(jsonschema.ValidationError)`), and at least 1 positive fixture that validates. Assertions must be "
        "state-based on validation results; no vacuous or always-true assertions; never skip a test.\n"
        "  3. Do not write the words unittest.mock, Mock(, MagicMock, patch(, monkeypatch or mocker anywhere in the file, "
        "including comments and docstrings. Use real objects only.\n"
        "  4. Hardcode the fixtures and expected constants in the test file; do NOT derive them by reading the schema you "
        "are testing (a test that computes its expectations from the schema cannot detect the schema being weakened).\n\n"
        "Non-vacuity check: the court will weaken a copy of the schema in each of these ways and require that at least one of "
        "your new tests then FAILS. Your fixtures must therefore detect every one of them:\n"
        f"{weakened}\n"
        "For an enum member, include a positive fixture using that exact member. For a removed `required` property, include a "
        "negative fixture that is otherwise valid but omits it. For `additionalProperties`, include a negative fixture that "
        "is otherwise valid but has one extra unknown property.\n\n"
        "When the commit exists, finish through the normal /xaas close protocol with your final head."
    )


def derive_items(repo: Path, min_negatives: int) -> list[dict]:
    items = []
    tests_dir = repo / "tests"
    for schema_path in sorted((repo / "contracts").glob("*.schema.json")):
        stem = schema_path.name[: -len(".schema.json")]
        existing = negative_fixture_count(tests_dir, stem)
        if existing >= min_negatives:
            continue
        rel = f"contracts/{schema_path.name}"
        schema = json.loads(schema_path.read_text())
        mutants = derive_mutants(stem, rel, schema)
        us = stem.replace("-", "_")
        items.append({
            "id": f"contract-{stem}",
            "schema": rel,
            "existing_negative_fixtures": existing,
            "goal": build_goal(stem, rel, mutants),
            "allowed_paths": [f"tests/test_contract_{us}.py"],
            "min_new_tests": 4,
            "min_kill_ratio": 1.0,
            "mutants": mutants,
        })
    return sorted(items, key=lambda i: i["id"])


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--repo", required=True)
    p.add_argument("--min-negatives", type=int, default=3)
    args = p.parse_args(argv)
    repo = Path(args.repo)
    if not (repo / "contracts").is_dir():
        print(f"error: {repo} has no contracts/ directory", file=sys.stderr)
        return 2
    doc = {"schemaVersion": SCHEMA_VERSION, "head": head_of(repo), "items": derive_items(repo, args.min_negatives)}
    print(json.dumps(doc, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
