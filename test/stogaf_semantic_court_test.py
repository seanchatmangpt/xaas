from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_stogaf_semantic_court_executes_cleanly(tmp_path: Path) -> None:
    output = tmp_path / "report.json"
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

    report = json.loads(output.read_text(encoding="utf-8"))
    assert report["standing"] == "ALIVE"
    assert report["shacl"]["conforms"] is True
    assert report["gate_count"] >= 5
    assert report["refusal_rows"] == 0
    assert report["data_triples"] > 0
