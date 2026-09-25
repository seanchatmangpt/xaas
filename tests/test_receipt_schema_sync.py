"""Real, file-based check that schema/receipt.schema.json's `required` and
`properties` stay in sync with the real eds.receipt.Receipt dataclass — the
exact drift class already guarded for schema/erc.schema.json's evidence_state
enum (test_schema_states_sync.py) and ontology/eds.ttl's EvidenceState concepts
(test_ontology_states_sync.py), but never applied to receipt.schema.json
itself. Before this test, nothing would fail if a future session added or
renamed a Receipt field without updating the schema, or vice versa — any
non-Python tool validating receipts purely against this schema (its own
stated purpose) would silently accept or reject the wrong shape.

No mocks: reads the real schema/receipt.schema.json off disk and builds a
real eds.receipt.Receipt (real sha256 digest via the real
compute_digest()/to_dict()), then compares the real key sets.
"""

from __future__ import annotations

import json
from pathlib import Path

from eds.receipt import Receipt

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "schema" / "receipt.schema.json"


def _load_schema() -> dict:
    assert SCHEMA_PATH.exists(), f"schema missing: {SCHEMA_PATH}"
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def _real_receipt_dict_keys() -> set[str]:
    receipt = Receipt(
        id="r-1",
        claim_id="c-1",
        artifact_reference="repo@deadbeef",
        source_revision="deadbeef",
        execution_command="pytest",
        outputs="ok",
    )
    return set(receipt.to_dict(with_digest=True).keys())


def test_receipt_schema_required_fields_are_all_real_receipt_keys() -> None:
    """Every field the schema *requires* must be a real key the dataclass
    actually produces — a required field the dataclass never emits would
    make every real Receipt schema-invalid."""
    schema = _load_schema()
    required = set(schema["required"])
    real_keys = _real_receipt_dict_keys()
    missing = required - real_keys
    assert not missing, (
        f"schema/receipt.schema.json requires {sorted(missing)} but the real "
        f"Receipt.to_dict() never produces {sorted(missing)} — schema/dataclass "
        f"drift. Real keys: {sorted(real_keys)}"
    )


def test_receipt_schema_declares_no_properties_beyond_the_real_dataclass() -> None:
    """Every property the schema *declares* must correspond to a real key the
    dataclass actually produces — an extra declared property with no real
    backing field is silent drift in the other direction."""
    schema = _load_schema()
    declared = set(schema["properties"].keys())
    real_keys = _real_receipt_dict_keys()
    extra = declared - real_keys
    assert not extra, (
        f"schema/receipt.schema.json declares properties {sorted(extra)} that "
        f"the real Receipt.to_dict() never produces — schema/dataclass drift. "
        f"Real keys: {sorted(real_keys)}"
    )
