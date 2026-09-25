"""Chicago-style: the real `eds` console entrypoint runs as a real subprocess
against real files — no mocked argparse/sys.exit."""

import json
import subprocess
import sys
from pathlib import Path


def run_cli(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, "-m", "eds.cli", *args],
        capture_output=True,
        text=True,
        cwd=cwd,
    )


def test_erc_new_then_validate_round_trip(tmp_path: Path):
    out = tmp_path / "erc.json"
    result = run_cli(
        "erc-new",
        "--id", "cli-1",
        "--hypothesis", "H",
        "--artifact", "repo@sha",
        "--state", "PROPOSED",
        "--no-falsifier",
        "--out", str(out),
    )
    assert result.returncode == 0, result.stderr
    assert out.exists()

    result2 = run_cli("erc-validate", str(out))
    assert result2.returncode == 0, result2.stderr
    assert "OK" in result2.stdout


def test_erc_validate_reports_violation_for_missing_falsifier(tmp_path: Path):
    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps({
        "id": "cli-2", "hypothesis": "H", "artifact_reference": "repo@sha",
        "evidence_state": "PROPOSED", "falsifier": "", "no_falsifier": False,
        "evidence": "", "verification": "", "source_revision": "", "receipt_refs": [],
    }))
    result = run_cli("erc-validate", str(bad))
    assert result.returncode == 1
    assert "falsifier" in result.stdout


def test_erc_advance_legal_transition_writes_new_state(tmp_path: Path):
    rec = tmp_path / "adv.json"
    result = run_cli(
        "erc-new",
        "--id", "adv-1",
        "--hypothesis", "H",
        "--artifact", "repo@sha",
        "--state", "PROPOSED",
        "--no-falsifier",
        "--out", str(rec),
    )
    assert result.returncode == 0, result.stderr

    result2 = run_cli(
        "erc-advance", str(rec),
        "--to", "IMPLEMENTED",
    )
    assert result2.returncode == 0, result2.stderr
    assert "ADVANCED" in result2.stdout
    assert "[IMPLEMENTED]" in result2.stdout

    on_disk = json.loads(rec.read_text())
    assert on_disk["evidence_state"] == "IMPLEMENTED"


def test_erc_advance_illegal_transition_reports_real_error_and_does_not_write(tmp_path: Path):
    rec = tmp_path / "adv2.json"
    result = run_cli(
        "erc-new",
        "--id", "adv-2",
        "--hypothesis", "H",
        "--artifact", "repo@sha",
        "--state", "IMPLEMENTED",
        "--no-falsifier",
        "--evidence", "some evidence",
        "--out", str(rec),
    )
    assert result.returncode == 0, result.stderr

    # IMPLEMENTED -> VERIFIED is a forbidden skip in the confirming path
    # (charter's core inequality: IMPLEMENTED != VERIFIED, and this jump
    # skips EXECUTABLE/OBSERVED too) — lifecycle.advance() must raise
    # IllegalStateTransition for real, not silently accept it.
    result2 = run_cli(
        "erc-advance", str(rec),
        "--to", "VERIFIED",
        "--expected", '{"ok": true}',
        "--observed", '{"ok": true}',
    )
    assert result2.returncode == 1
    assert "ILLEGAL" in result2.stdout
    assert "not a legal" in result2.stdout

    # record on disk must be untouched by the rejected transition
    on_disk = json.loads(rec.read_text())
    assert on_disk["evidence_state"] == "IMPLEMENTED"


def test_metrics_over_real_registry_directory(tmp_path: Path):
    registry = tmp_path / "registry"
    run_cli("erc-new", "--id", "m1", "--hypothesis", "H", "--artifact", "r",
             "--state", "IMPLEMENTED", "--no-falsifier", "--out", str(registry / "m1.json"))
    result = run_cli("metrics", str(registry), "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["total_claims"] == 1
    assert data["parse_failures"] == []


def test_metrics_reports_real_parse_failures_and_nonzero_exit(tmp_path: Path):
    registry = tmp_path / "registry"
    registry.mkdir(parents=True)
    run_cli("erc-new", "--id", "m1", "--hypothesis", "H", "--artifact", "r",
             "--state", "IMPLEMENTED", "--no-falsifier", "--out", str(registry / "m1.json"))
    (registry / "malformed.json").write_text("{ not valid json")

    result = run_cli("metrics", str(registry), "--json")
    assert result.returncode == 1
    data = json.loads(result.stdout)
    assert data["total_claims"] == 1
    assert len(data["parse_failures"]) == 1
    assert data["parse_failures"][0]["path"].endswith("malformed.json")

    text_result = run_cli("metrics", str(registry))
    assert text_result.returncode == 1
    assert "parse failures:          1" in text_result.stdout
    assert "malformed.json" in text_result.stdout
