"""Executable Design Science (EDS) — charter v0.1, 2026-09-12.

This package implements the parts of the charter that admit a mechanical
check: the closed evidence-state lattice (§8), the ERC record shape (§14),
the receipt shape (§9), and the six program metrics (§21). It does not and
cannot implement the parts of the charter that are methodological judgment
(what counts as a good falsifier, whether evidence actually supports a
proposition) — those stay human/agent judgment calls, recorded in the
records this package validates and aggregates.
"""

from eds.states import EvidenceState, ORDERED_STATES
from eds.erc import ERC, ERCValidationError
from eds.receipt import Receipt, compute_digest
from eds.metrics import ProgramSnapshot, compute_snapshot

__all__ = [
    "EvidenceState",
    "ORDERED_STATES",
    "ERC",
    "ERCValidationError",
    "Receipt",
    "compute_digest",
    "ProgramSnapshot",
    "compute_snapshot",
]
