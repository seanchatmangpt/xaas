"""Copy the V23-X receipt's extraction counts from the checked summary (never retype them).

Usage (xaas root): python3 receipts/v26.9.23/V23-X.gate/derive_extraction.py

Reads receipts/v26.9.23/V23-X.gate/prd-ard.summary.json, written by
  prose_spans.py check ... --summary <that path>
refuses (exit 1) unless a fresh `check --summary` over the committed source and
candidates reproduces the summary bytes, the summary says check OK, it binds the
committed candidates and source by sha256, and it partitions (required +
not_required == candidates); then
rewrites extraction.{candidates,kinds,gate_coverage,root_required,not_required,
multi_required,summary} in receipts/v26.9.23/V23-X.json. Repair round 1: the
prior receipt typed root_required = 12 where the artifact has 15 (court GATE lens,
broken_term mu_on_O).
"""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

GATE_DIR = Path("receipts/v26.9.23/V23-X.gate")
SUMMARY = GATE_DIR / "prd-ard.summary.json"
RECEIPT = Path("receipts/v26.9.23/V23-X.json")
SOURCE = Path("docs/sjira/v26.9.23/prd-ard.md")
CANDIDATES = Path("docs/sjira/v26.9.23/candidates/prd-ard.ttl")
SCRIPT = Path("scripts/sjira/prose_spans.py")
ROOT = "GC-26.9.23"


def digest(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    summary = json.loads(SUMMARY.read_text(encoding="utf-8"))
    refusals = []
    with tempfile.TemporaryDirectory() as tmp:
        fresh = Path(tmp) / "summary.json"
        run = subprocess.run(
            [sys.executable, str(SCRIPT), "check", "--source", str(SOURCE), "--candidates", str(CANDIDATES)]
            + ["--require-gates", str(summary.get("require_gates", 0)), "--summary", str(fresh)],
            capture_output=True,
            text=True,
            check=False,
        )
        if run.returncode != 0 or not fresh.exists() or fresh.read_bytes() != SUMMARY.read_bytes():
            refusals.append(f"fresh check --summary (exit {run.returncode}) does not reproduce the committed summary")
    if summary.get("check") != "OK" or summary.get("refusals") != 0:
        refusals.append(f"summary check={summary.get('check')} refusals={summary.get('refusals')}")
    if summary.get("candidates_sha256") != digest(CANDIDATES):
        refusals.append(f"candidates_sha256 {summary.get('candidates_sha256')} != {digest(CANDIDATES)}")
    if summary.get("source_sha256") != digest(SOURCE):
        refusals.append(f"source_sha256 {summary.get('source_sha256')} != {digest(SOURCE)}")
    if summary["required"] + summary["not_required"] != summary["candidates"]:
        refusals.append("required + not_required != candidates")
    if summary["verified"] != summary["candidates"]:
        refusals.append("verified != candidates")
    if refusals:
        for r in refusals:
            print(f"REFUSED {SUMMARY}: {r}")
        return 1
    receipt = json.loads(RECEIPT.read_text(encoding="utf-8"))
    ext = receipt["extraction"]
    targets = summary["required_by"]
    gates = {k: v for k, v in targets.items() if k != ROOT}
    ext["candidates"] = summary["candidates"]
    ext["kinds"] = summary["kinds"]
    ext["gate_coverage"] = gates
    ext["not_required"] = summary["not_required"]
    ext["multi_required"] = summary["multi_required"]
    ext["root_required"] = (
        f"{targets.get(ROOT, 0)} candidates carry sj:requiredBy <v23:{ROOT}> (PRD §13 stop condition, "
        "§27 REQUIRED_UNKNOWN / STOP counters, ARD §19, §28); "
        f"{summary['not_required']} carry no sj:requiredBy (non-required: §10 non-goals, WD reference flow, "
        f"migration notes); {sum(gates.values())} gate memberships; multi_required {summary['multi_required']}; "
        f"required {summary['required']} + not_required {summary['not_required']} = {summary['candidates']}"
    )
    ext["summary"] = f"{SUMMARY.as_posix()} {digest(SUMMARY)} (prose_spans.py check --summary; counts copied by "
    ext["summary"] += f"{GATE_DIR.as_posix()}/derive_extraction.py)"
    RECEIPT.write_text(json.dumps(receipt, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"DERIVED: candidates={summary['candidates']} root={targets.get(ROOT, 0)} "
        f"not_required={summary['not_required']} gates={sum(gates.values())} multi={summary['multi_required']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
