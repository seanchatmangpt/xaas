"""Chicago-style: builds a real registry directory of real ERC JSON files on
disk (via ERC.write()) and asserts on the real output of sweep_registry() /
the real `eds registry-sweep` subprocess. No mocks."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from eds.erc import ERC
from eds.registry_sweep import sweep_registry
from eds.states import EvidenceState


def _write(dir_path: Path, id_: str, state: EvidenceState, evidence: str) -> Path:
    erc = ERC(
        id=id_,
        hypothesis=f"hypothesis for {id_}",
        artifact_reference="repo@deadbeef",
        evidence_state=state,
        falsifier="a real falsifier description",
        evidence=evidence,
    )
    return erc.write(dir_path / f"{id_}.json")


def test_sweep_reports_real_state_counts(tmp_path: Path) -> None:
    registry = tmp_path / "receipts"
    _write(registry, "a-proposed", EvidenceState.PROPOSED, "")
    _write(registry, "b-implemented", EvidenceState.IMPLEMENTED, "ran it once, logs at /tmp/a.log")
    _write(registry, "c-implemented-no-evidence", EvidenceState.IMPLEMENTED, "")
    _write(registry, "d-falsified", EvidenceState.FALSIFIED, "counterexample found")

    report = sweep_registry(registry)

    assert report.total_files == 4
    assert report.failures == []
    assert report.state_counts == {
        "PROPOSED": 1,
        "IMPLEMENTED": 2,
        "FALSIFIED": 1,
    }


def test_sweep_finds_stalled_records_with_evidence_not_yet_advanced(tmp_path: Path) -> None:
    registry = tmp_path / "receipts"
    # Has real evidence, IMPLEMENTED has a legal forward target (EXECUTABLE)
    # -> a real stalled candidate.
    _write(registry, "stalled-one", EvidenceState.IMPLEMENTED, "concrete run output here")
    # No evidence at all -> not a candidate (nothing to advance on).
    _write(registry, "no-evidence", EvidenceState.IMPLEMENTED, "")
    # FALSIFIED is a terminal side state -> no legal forward target, not a candidate
    # even though it has evidence text.
    _write(registry, "terminal-falsified", EvidenceState.FALSIFIED, "refuting counterexample")

    report = sweep_registry(registry)

    stalled_ids = {r.id for r in report.stalled_with_evidence}
    assert stalled_ids == {"stalled-one"}

    by_id = {r.id: r for r in report.records}
    assert by_id["stalled-one"].has_evidence is True
    assert by_id["stalled-one"].advanceable is True
    assert by_id["no-evidence"].has_evidence is False
    assert by_id["no-evidence"].advanceable is False
    assert by_id["terminal-falsified"].advanceable is False


def test_sweep_reports_real_parse_failures_without_dropping_them(tmp_path: Path) -> None:
    registry = tmp_path / "receipts"
    registry.mkdir(parents=True)
    _write(registry, "good", EvidenceState.PROPOSED, "")
    (registry / "not-an-erc.json").write_text("{not valid json")

    report = sweep_registry(registry)

    assert report.total_files == 2
    assert len(report.records) == 1
    assert len(report.failures) == 1
    assert report.failures[0].path.endswith("not-an-erc.json")


def test_sweep_on_missing_directory_reports_zero_not_a_crash(tmp_path: Path) -> None:
    report = sweep_registry(tmp_path / "does-not-exist")
    assert report.total_files == 0
    assert report.records == []
    assert report.failures == []


def test_cli_registry_sweep_subprocess_real_json_output(tmp_path: Path) -> None:
    """Real `eds registry-sweep --json` subprocess invocation (Chicago-style,
    same pattern as test_cli.py's other subprocess tests) against a real
    registry directory."""
    registry = tmp_path / "receipts"
    _write(registry, "x", EvidenceState.IMPLEMENTED, "real evidence text")
    _write(registry, "y", EvidenceState.PROPOSED, "")

    result = subprocess.run(
        [sys.executable, "-m", "eds.cli", "registry-sweep", str(registry), "--json"],
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["total_files"] == 2
    assert payload["state_counts"] == {"IMPLEMENTED": 1, "PROPOSED": 1}
    assert [r["id"] for r in payload["stalled_with_evidence"]] == ["x"]


def test_erc_read_coerces_list_shaped_evidence_field(tmp_path: Path) -> None:
    """Real bug: some real ERC JSON files in the registry (written by an
    earlier agent pass) have "evidence" as a list of strings instead of a
    plain string. ERC.read() must coerce it into a real joined string, not
    crash downstream .strip() callers."""
    path = tmp_path / "list-evidence.json"
    path.write_text(
        json.dumps(
            {
                "id": "list-evidence",
                "hypothesis": "some hypothesis",
                "artifact_reference": "repo@deadbeef",
                "evidence_state": "IMPLEMENTED",
                "falsifier": "a real falsifier",
                "evidence": ["ran test A, passed", "ran test B, passed"],
            }
        )
    )

    erc = ERC.read(path)

    assert isinstance(erc.evidence, str)
    assert "ran test A, passed" in erc.evidence
    assert "ran test B, passed" in erc.evidence
    # the real downstream call that used to crash on a list:
    assert erc.evidence.strip() != ""


def test_sweep_does_not_crash_on_mixed_shape_directory_and_counts_anomaly(
    tmp_path: Path,
) -> None:
    """Real bug repro: a directory mixing well-formed ERC records with a
    record whose "evidence" field is a list (an earlier agent pass's shape)
    must not raise AttributeError out of sweep_registry() — it must parse
    every record and report the list-evidence record as a counted anomaly,
    not silently as clean and not as a crash."""
    registry = tmp_path / "receipts"
    registry.mkdir(parents=True)
    _write(registry, "normal-one", EvidenceState.IMPLEMENTED, "concrete run output")
    (registry / "list-evidence.json").write_text(
        json.dumps(
            {
                "id": "list-evidence",
                "hypothesis": "some hypothesis",
                "artifact_reference": "repo@deadbeef",
                "evidence_state": "IMPLEMENTED",
                "falsifier": "a real falsifier",
                "evidence": ["ran test A, passed", "ran test B, passed"],
            }
        )
    )

    report = sweep_registry(registry)  # must not raise

    assert report.total_files == 2
    assert len(report.failures) == 0
    assert len(report.records) == 2
    assert len(report.anomalies) == 1
    assert report.anomalies[0].path.endswith("list-evidence.json")

    by_id = {r.id: r for r in report.records}
    assert by_id["list-evidence"].has_evidence is True
    assert report.state_counts["IMPLEMENTED"] == 2


def test_sweep_reports_real_charter_violations_via_erc_validate(tmp_path: Path) -> None:
    """Real bug this closes: registry-sweep never ran ERC.validate() on the
    records it swept, so a real charter-violating record (falsifier text
    present together with no_falsifier=True — the exact contradiction found
    against the real /Users/sac/eds-registry/receipts/ corpus in
    tests/test_real_registry_corpus.py) was invisible to the day-to-day sweep
    a human/agent actually runs."""
    registry = tmp_path / "receipts"
    registry.mkdir(parents=True)
    clean = ERC(
        id="clean-record",
        hypothesis="a real hypothesis",
        artifact_reference="repo@deadbeef",
        evidence_state=EvidenceState.PROPOSED,
        falsifier="a real falsifier description",
    )
    clean.write(registry / "clean-record.json")

    contradictory = ERC(
        id="contradictory-record",
        hypothesis="a real hypothesis",
        artifact_reference="repo@deadbeef",
        evidence_state=EvidenceState.PROPOSED,
        falsifier="a real falsifier description",
        no_falsifier=True,  # contradicts the non-empty falsifier above
    )
    contradictory.write(registry / "contradictory-record.json")

    report = sweep_registry(registry)

    assert report.total_files == 2
    assert len(report.failures) == 0  # both parse fine; only one is self-contradictory
    violation_ids = {v.id for v in report.charter_violations}
    assert violation_ids == {"contradictory-record"}
    violation = report.charter_violations[0]
    assert any("contradictory record" in v for v in violation.violations)

    payload = report.to_dict()
    assert [v["id"] for v in payload["charter_violations"]] == ["contradictory-record"]


def test_sweep_stalled_records_carry_a_concrete_suggested_next_state(tmp_path: Path) -> None:
    """Real gap this closes: `stalled_with_evidence` said a record COULD move
    forward but never said WHERE — a human/agent reviewing the sweep had to
    re-derive the confirming-path transition graph (lifecycle._CONFIRMING_PATH)
    by hand before calling `eds erc-advance --to ...`. `suggested_next_state`
    names the one concrete confirming-path target, computed via the real
    `lifecycle.next_confirming_state()` — never auto-applied, purely advisory."""
    registry = tmp_path / "receipts"
    _write(registry, "implemented-with-evidence", EvidenceState.IMPLEMENTED, "real run output")
    _write(registry, "observed-with-evidence", EvidenceState.OBSERVED, "real observation log")
    _write(registry, "no-evidence", EvidenceState.IMPLEMENTED, "")
    _write(registry, "terminal-falsified", EvidenceState.FALSIFIED, "refuting counterexample")

    report = sweep_registry(registry)

    by_id = {r.id: r for r in report.records}
    assert by_id["implemented-with-evidence"].suggested_next_state == "EXECUTABLE"
    assert by_id["observed-with-evidence"].suggested_next_state == "VERIFIED"
    # No forward suggestion for a non-advanceable record even without evidence
    # -- the field reflects the transition graph, not the has_evidence gate.
    assert by_id["no-evidence"].suggested_next_state == "EXECUTABLE"
    # A terminal side state has no confirming-path successor at all.
    assert by_id["terminal-falsified"].suggested_next_state is None

    payload = report.to_dict()
    stalled_payload = {r["id"]: r for r in payload["stalled_with_evidence"]}
    assert stalled_payload["implemented-with-evidence"]["suggested_next_state"] == "EXECUTABLE"


def test_format_report_shows_suggested_next_state_for_stalled_records(tmp_path: Path) -> None:
    registry = tmp_path / "receipts"
    _write(registry, "implemented-with-evidence", EvidenceState.IMPLEMENTED, "real run output")

    from eds.registry_sweep import format_report

    report = sweep_registry(registry)
    text = format_report(report)
    assert "implemented-with-evidence" in text
    assert "-> EXECUTABLE" in text


def test_cli_registry_sweep_json_includes_charter_violations(tmp_path: Path) -> None:
    """Real `eds registry-sweep --json` subprocess exposes charter_violations,
    not just parse failures/anomalies."""
    registry = tmp_path / "receipts"
    registry.mkdir(parents=True)
    ERC(
        id="bad",
        hypothesis="h",
        artifact_reference="repo@deadbeef",
        evidence_state=EvidenceState.PROPOSED,
        falsifier="present",
        no_falsifier=True,
    ).write(registry / "bad.json")

    result = subprocess.run(
        [sys.executable, "-m", "eds.cli", "registry-sweep", str(registry), "--json"],
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert [v["id"] for v in payload["charter_violations"]] == ["bad"]
