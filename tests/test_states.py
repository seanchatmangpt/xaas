from eds.states import EvidenceState, STATES_REQUIRING_EVIDENCE


def test_closed_vocabulary_has_exactly_eleven_states():
    # Extended from the charter's original nine to the full eleven states
    # named in the Executable Design Science paper's §7 (adding BLOCKED and
    # UNSUPPORTED as side states alongside FALSIFIED/UNKNOWN) — a twelfth
    # would be a silent vocabulary drift, a missing one would break
    # downstream classification.
    assert len(list(EvidenceState)) == 11


def test_implemented_and_verified_are_distinct_values():
    assert EvidenceState.IMPLEMENTED != EvidenceState.VERIFIED
    assert EvidenceState.EXECUTABLE != EvidenceState.REPRODUCED


def test_states_requiring_evidence_excludes_proposed_and_implemented():
    assert EvidenceState.PROPOSED not in STATES_REQUIRING_EVIDENCE
    assert EvidenceState.IMPLEMENTED not in STATES_REQUIRING_EVIDENCE
    assert EvidenceState.VERIFIED in STATES_REQUIRING_EVIDENCE
