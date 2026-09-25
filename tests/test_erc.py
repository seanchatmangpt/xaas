"""Chicago-style: real files on disk, real round-trip through JSON, no mocks."""

from pathlib import Path

import pytest

from eds.erc import ERC, ERCValidationError
from eds.states import EvidenceState


def test_erc_without_falsifier_or_no_falsifier_flag_fails_validation():
    erc = ERC(
        id="erc-1",
        hypothesis="X improves Y",
        artifact_reference="repo@sha",
        evidence_state=EvidenceState.PROPOSED,
    )
    problems = erc.validate()
    assert any("falsifier" in p for p in problems)


def test_erc_with_explicit_no_falsifier_passes_that_check():
    erc = ERC(
        id="erc-2",
        hypothesis="X improves Y",
        artifact_reference="repo@sha",
        evidence_state=EvidenceState.PROPOSED,
        no_falsifier=True,
    )
    problems = erc.validate()
    assert not any("falsifier" in p for p in problems)


def test_verified_state_without_evidence_is_rejected():
    erc = ERC(
        id="erc-3",
        hypothesis="X improves Y",
        artifact_reference="repo@sha",
        evidence_state=EvidenceState.VERIFIED,
        falsifier="Y regresses under load",
        evidence="",
    )
    with pytest.raises(ERCValidationError):
        erc.require_valid()


def test_verified_state_with_real_evidence_is_accepted():
    erc = ERC(
        id="erc-4",
        hypothesis="X improves Y",
        artifact_reference="repo@sha",
        evidence_state=EvidenceState.VERIFIED,
        falsifier="Y regresses under load",
        evidence="pytest -k test_y -> 12 passed",
        verification="all 12 assertions on measured Y hold",
    )
    erc.require_valid()  # must not raise


def test_erc_round_trips_through_real_disk_write_and_read(tmp_path: Path):
    original = ERC(
        id="erc-5",
        hypothesis="FOND-HTN improves admitted branch coverage over deterministic replanning",
        artifact_reference="ferroplan@abc123",
        evidence_state=EvidenceState.OBSERVED,
        falsifier="Coverage_FONDHTN <= Coverage_Replanning under predeclared benchmark",
        evidence="benchmark run: fondhtn_coverage=0.82 replanning_coverage=0.71",
        receipt_refs=("receipt-1", "receipt-2"),
    )
    path = tmp_path / "erc-5.json"
    original.write(path)

    # real file actually exists with real content — not a mock filesystem
    assert path.exists()
    on_disk = path.read_text()
    assert "FOND-HTN" in on_disk
    assert '"evidence_state": "OBSERVED"' in on_disk

    loaded = ERC.read(path)
    assert loaded == original


def test_erc_from_dict_accepts_schema_shaped_artifact_field():
    # erc.schema.json's shape nests artifact.reference; the workflow-produced
    # records used this shape, so from_dict must accept it directly.
    d = {
        "id": "erc-6",
        "hypothesis": "H",
        "artifact": {"reference": "repo#42", "source_revision": "deadbeef"},
        "evidence_state": "IMPLEMENTED",
        "falsifier": "",
        "no_falsifier": True,
    }
    erc = ERC.from_dict(d)
    assert erc.artifact_reference == "repo#42"
    assert erc.source_revision == "deadbeef"
