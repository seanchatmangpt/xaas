"""Charter §8: closed evidence-state vocabulary. States must not collapse —
IMPLEMENTED != VERIFIED, EXECUTABLE != REPRODUCED, TEST_PASS != SCIENTIFIC_PROOF.
"""

from __future__ import annotations

from enum import Enum


class EvidenceState(str, Enum):
    PROPOSED = "PROPOSED"
    IMPLEMENTED = "IMPLEMENTED"
    EXECUTABLE = "EXECUTABLE"
    OBSERVED = "OBSERVED"
    VERIFIED = "VERIFIED"
    REPRODUCIBLE = "REPRODUCIBLE"
    REPRODUCED = "REPRODUCED"
    FALSIFIED = "FALSIFIED"
    BLOCKED = "BLOCKED"
    UNSUPPORTED = "UNSUPPORTED"
    UNKNOWN = "UNKNOWN"


# Charter §8 lists these in a progression, but FALSIFIED, BLOCKED, UNSUPPORTED,
# and UNKNOWN are side states reachable from any point, not a further step past
# REPRODUCED — this ordering is only meaningful for the "how far along the
# confirming path" the state is, used by metrics.py's ExecutableClaimRatio,
# and must never be used to imply FALSIFIED > REPRODUCED or similar nonsense.
ORDERED_STATES = (
    EvidenceState.PROPOSED,
    EvidenceState.IMPLEMENTED,
    EvidenceState.EXECUTABLE,
    EvidenceState.OBSERVED,
    EvidenceState.VERIFIED,
    EvidenceState.REPRODUCIBLE,
    EvidenceState.REPRODUCED,
)

# States charter §9 requires real evidence to exist for, not merely be
# claimed — enforced in erc.py's ERC.validate().
STATES_REQUIRING_EVIDENCE = frozenset(
    {
        EvidenceState.OBSERVED,
        EvidenceState.VERIFIED,
        EvidenceState.REPRODUCIBLE,
        EvidenceState.REPRODUCED,
    }
)

# Side states reachable from any non-terminal point on ORDERED_STATES — never
# a "further step" past REPRODUCED. See lifecycle.py for the enforced
# transition graph these participate in.
SIDE_STATES = frozenset(
    {
        EvidenceState.FALSIFIED,
        EvidenceState.BLOCKED,
        EvidenceState.UNSUPPORTED,
        EvidenceState.UNKNOWN,
    }
)
