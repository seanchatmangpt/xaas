"""Real, file-based check that ontology/eds.ttl's EvidenceStateScheme stays in
sync with src/eds/states.py's EvidenceState enum — the exact drift named as an
open gap in README.md's Layout section ("Not yet updated for the
BLOCKED/UNSUPPORTED states added below"). No rdflib dependency: this reads the
real ttl file as text and asserts each enum member appears as a real
skos:Concept declaration in the real file on disk, Chicago-style (no mocks).
"""

from __future__ import annotations

import re
from pathlib import Path

from eds.states import EvidenceState

TTL_PATH = Path(__file__).resolve().parent.parent / "ontology" / "eds.ttl"

# Matches a line like: `eds:BLOCKED  a skos:Concept ; skos:inScheme eds:EvidenceStateScheme ; skos:prefLabel "BLOCKED"@en ;`
CONCEPT_LINE_RE = re.compile(
    r'^eds:(\w+)\s+a\s+skos:Concept\s*;\s*skos:inScheme\s+eds:EvidenceStateScheme\s*;\s*'
    r'skos:prefLabel\s+"(\w+)"@en',
    re.MULTILINE,
)


def _ttl_text() -> str:
    assert TTL_PATH.exists(), f"ontology file missing: {TTL_PATH}"
    return TTL_PATH.read_text(encoding="utf-8")


def _declared_concepts() -> dict[str, str]:
    """Real name -> real prefLabel pairs actually declared in the ttl file."""
    text = _ttl_text()
    return {name: label for name, label in CONCEPT_LINE_RE.findall(text)}


def test_every_evidence_state_has_a_skos_concept_in_the_ttl() -> None:
    declared = _declared_concepts()
    enum_names = {state.value for state in EvidenceState}
    missing = enum_names - set(declared)
    assert not missing, (
        f"ontology/eds.ttl's EvidenceStateScheme is missing skos:Concept "
        f"declarations for: {sorted(missing)} — src/eds/states.py:EvidenceState "
        f"is the source of truth these must mirror."
    )
    mismatched_labels = {
        name for name, label in declared.items() if name in enum_names and label != name
    }
    assert not mismatched_labels, (
        f"ontology/eds.ttl has a skos:prefLabel that doesn't match its own "
        f"eds:<name>: {sorted(mismatched_labels)}"
    )


def test_ttl_declares_no_evidence_state_concepts_beyond_the_enum() -> None:
    declared_names = set(_declared_concepts())
    enum_names = {state.value for state in EvidenceState}
    extra = declared_names - enum_names
    assert not extra, (
        f"ontology/eds.ttl declares skos:Concept states not present in "
        f"src/eds/states.py:EvidenceState: {sorted(extra)}"
    )
    assert declared_names == enum_names
