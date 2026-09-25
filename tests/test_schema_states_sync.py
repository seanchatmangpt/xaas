"""Real, file-based check that schema/erc.schema.json's evidence_state enum
stays in sync with src/eds/states.py's EvidenceState enum.

Same drift class as test_ontology_states_sync.py (which guards ontology/eds.ttl)
but applied to the JSON Schema mirror instead: erc.schema.json's
evidence_state enum previously listed only 9 of the 11 real states (missing
BLOCKED and UNSUPPORTED, added to states.py when it was extended from the
charter's original 9 values to the paper's full 11) — a real drift that no
test caught, unlike the ttl which already had this guard. No mocks: reads the
real JSON schema file on disk and compares against the real enum.
"""

from __future__ import annotations

import json
from pathlib import Path

from eds.states import EvidenceState

SCHEMA_PATH = Path(__file__).resolve().parent.parent / "schema" / "erc.schema.json"


def _schema_evidence_states() -> set[str]:
    assert SCHEMA_PATH.exists(), f"schema file missing: {SCHEMA_PATH}"
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    return set(schema["properties"]["evidence_state"]["enum"])


def test_schema_evidence_state_enum_has_every_real_state() -> None:
    declared = _schema_evidence_states()
    enum_names = {state.value for state in EvidenceState}
    missing = enum_names - declared
    assert not missing, (
        f"schema/erc.schema.json's evidence_state enum is missing: "
        f"{sorted(missing)} — src/eds/states.py:EvidenceState is the source "
        f"of truth these must mirror."
    )


def test_schema_evidence_state_enum_has_no_extra_states() -> None:
    declared = _schema_evidence_states()
    enum_names = {state.value for state in EvidenceState}
    extra = declared - enum_names
    assert not extra, (
        f"schema/erc.schema.json's evidence_state enum declares states not "
        f"present in src/eds/states.py:EvidenceState: {sorted(extra)}"
    )
    assert declared == enum_names
