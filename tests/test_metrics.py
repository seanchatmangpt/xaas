"""Chicago-style: builds a real corpus of ERC files on disk, loads it back
through the real filesystem walk, computes real ratios — no mocked corpus."""

from pathlib import Path

from eds.erc import ERC
from eds.metrics import compute_snapshot, load_corpus
from eds.states import EvidenceState


def _write(tmp_path: Path, **kwargs) -> Path:
    erc = ERC(**kwargs)
    path = tmp_path / f"{erc.id}.json"
    erc.write(path)
    return path


def test_snapshot_on_empty_corpus_is_zero_not_fabricated():
    snapshot = compute_snapshot([])
    assert snapshot.total_claims == 0
    assert snapshot.executable_claim_ratio == 0.0
    assert snapshot.falsifier_coverage == 0.0


def test_falsifier_coverage_counts_only_real_falsifiers():
    records = [
        ERC(id="a", hypothesis="h", artifact_reference="r", evidence_state=EvidenceState.PROPOSED, falsifier="F1"),
        ERC(id="b", hypothesis="h", artifact_reference="r", evidence_state=EvidenceState.PROPOSED, no_falsifier=True),
    ]
    snapshot = compute_snapshot(records)
    assert snapshot.falsifier_coverage == 0.5  # exactly one of two has a real falsifier


def test_receipt_coverage_reflects_actual_receipt_refs():
    records = [
        ERC(id="a", hypothesis="h", artifact_reference="r", evidence_state=EvidenceState.PROPOSED,
            no_falsifier=True, receipt_refs=("rc-1",)),
        ERC(id="b", hypothesis="h", artifact_reference="r", evidence_state=EvidenceState.PROPOSED,
            no_falsifier=True),
    ]
    snapshot = compute_snapshot(records)
    assert snapshot.receipt_coverage == 0.5


def test_load_corpus_reads_real_files_written_to_a_real_directory(tmp_path: Path):
    registry = tmp_path / "registry" / "repoA"
    _write(registry, id="a1", hypothesis="h1", artifact_reference="repoA#1",
           evidence_state=EvidenceState.IMPLEMENTED, no_falsifier=True)
    _write(registry, id="a2", hypothesis="h2", artifact_reference="repoA#2",
           evidence_state=EvidenceState.VERIFIED, falsifier="f", evidence="real output")

    loaded, failures = load_corpus(tmp_path / "registry")
    assert {r.id for r in loaded} == {"a1", "a2"}
    assert failures == []

    snapshot = compute_snapshot(loaded, failures)
    assert snapshot.total_claims == 2
    assert snapshot.state_counts["IMPLEMENTED"] == 1
    assert snapshot.state_counts["VERIFIED"] == 1
    assert snapshot.parse_failures == []


def test_load_corpus_reports_real_parse_failures_instead_of_silently_dropping_them(tmp_path: Path):
    registry = tmp_path / "registry"
    registry.mkdir(parents=True)
    _write(registry, id="good", hypothesis="h", artifact_reference="r",
           evidence_state=EvidenceState.PROPOSED, no_falsifier=True)
    bad_path = registry / "malformed.json"
    bad_path.write_text("{ not valid json")

    loaded, failures = load_corpus(registry)
    assert {r.id for r in loaded} == {"good"}
    assert len(failures) == 1
    assert failures[0].path == str(bad_path)
    assert failures[0].error  # real exception text, not empty

    snapshot = compute_snapshot(loaded, failures)
    assert snapshot.total_claims == 1
    assert len(snapshot.parse_failures) == 1
    assert snapshot.parse_failures[0].path == str(bad_path)
