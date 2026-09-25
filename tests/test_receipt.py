"""Chicago-style: the real sha256 function runs, real tamper detection on a
real file on disk — no mocked hasher."""

import json
from pathlib import Path

import pytest

from eds.receipt import Receipt, compute_digest


def make_receipt() -> Receipt:
    return Receipt(
        id="receipt-1",
        claim_id="erc-5",
        artifact_reference="ferroplan@abc123",
        source_revision="abc123def456",
        execution_command="cargo bench --bench fondhtn_coverage",
        outputs="fondhtn_coverage=0.82 replanning_coverage=0.71",
        environment={"os": "darwin-25.2.0", "toolchain": "rustc 1.82"},
        validators=("criterion-bench",),
        supports_proposition="FONDHTN coverage exceeded replanning coverage on this benchmark run only",
    )


def test_digest_is_deterministic_for_identical_fields():
    r1 = make_receipt()
    r2 = make_receipt()
    assert compute_digest(r1.to_dict(with_digest=False)) == compute_digest(r2.to_dict(with_digest=False))


def test_digest_changes_if_any_field_changes():
    r1 = make_receipt()
    r2 = make_receipt()
    r2.outputs = "fondhtn_coverage=0.50 replanning_coverage=0.71"  # tampered
    assert compute_digest(r1.to_dict(with_digest=False)) != compute_digest(r2.to_dict(with_digest=False))


def test_receipt_round_trips_and_verifies_on_real_disk(tmp_path: Path):
    receipt = make_receipt()
    path = tmp_path / "receipt-1.json"
    receipt.write(path)

    assert path.exists()
    loaded = Receipt.read(path)  # raises on digest mismatch — this IS the check
    assert loaded.outputs == receipt.outputs


def test_tampering_with_the_file_on_disk_is_caught(tmp_path: Path):
    receipt = make_receipt()
    path = tmp_path / "receipt-1.json"
    receipt.write(path)

    # real tamper: rewrite one field directly in the file, leave the digest alone
    text = path.read_text()
    tampered = text.replace("0.82", "0.99")
    assert tampered != text
    path.write_text(tampered)

    with pytest.raises(ValueError, match="digest mismatch"):
        Receipt.read(path)


def test_stripping_the_digest_field_entirely_is_also_caught(tmp_path: Path):
    """Previously Receipt.read() only checked the digest when a "digest" key
    was present at all (`d.pop("digest", None)`, then `if stored_digest is
    not None`) — an attacker (or a corrupted write) that removed the digest
    key while tampering with a real field bypassed verification completely
    and silently loaded. A real receipt written by write() always carries a
    digest, so its absence must be treated as tampering, not an optional
    field."""
    receipt = make_receipt()
    path = tmp_path / "receipt-1.json"
    receipt.write(path)

    d = json.loads(path.read_text())
    del d["digest"]
    d["outputs"] = "TAMPERED — digest stripped to bypass verification"
    path.write_text(json.dumps(d))

    with pytest.raises(ValueError, match="missing digest"):
        Receipt.read(path)
