from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _run_court(output: Path) -> None:
    subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts" / "stogaf_semantic_court.py"),
            "--pack",
            str(ROOT / "priv" / "packs" / "wd_cs2_pack"),
            "--output",
            str(output),
        ],
        check=True,
        cwd=ROOT,
    )


def test_stogaf_semantic_court_executes_cleanly(tmp_path: Path) -> None:
    output = tmp_path / "report.json"
    _run_court(output)

    report = json.loads(output.read_text(encoding="utf-8"))
    assert report["standing"] == "ALIVE"
    assert report["shacl"]["conforms"] is True
    assert report["gate_count"] >= 9
    assert report["schema"] == "STOGAF_SEMANTIC_COURT_V2"
    assert report["refusal_rows"] == 0
    assert report["data_triples"] > 0


def test_court_report_is_digest_bound_and_replays_byte_identically(tmp_path: Path) -> None:
    first, second = tmp_path / "a.json", tmp_path / "b.json"
    _run_court(first)
    _run_court(second)
    assert first.read_bytes() == second.read_bytes()

    report = json.loads(first.read_text(encoding="utf-8"))
    digest = report.pop("report_sha256")
    canonical = json.dumps(report, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    assert hashlib.sha256(canonical.encode("utf-8")).hexdigest() == digest

    inputs = report["inputs_sha256"]
    for name in ("pack/claims.ttl", "pack/case-study.ttl", "pack/case-study-shapes.ttl"):
        assert name in inputs
    assert any(name.startswith("deck/") for name in inputs)
    for name, value in inputs.items():
        if name.startswith("pack/"):
            path = ROOT / "priv" / "packs" / "wd_cs2_pack" / name.removeprefix("pack/")
            assert hashlib.sha256(path.read_bytes()).hexdigest() == value, name
