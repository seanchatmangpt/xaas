"""Charter §21: program metrics computed over a real corpus of ERC records.
No metric here is estimated — each is a plain ratio over records actually on
disk, and an empty corpus produces 0.0 (never a fabricated default) with the
caller responsible for treating n=0 as UNKNOWN rather than "0% good".

Named gap closed this session: ``load_corpus`` previously walked
``registry_dir.rglob("*.json")`` and silently swallowed any parse exception
(``except Exception: continue``) with zero record of which files failed or
why. Every ratio in ``ProgramSnapshot`` is denominated over whatever
``load_corpus`` happened to return, so a registry with malformed records
would silently under-report ``total_claims`` — the exact "fabricated
default" this module's own docstring says to avoid, just moved one level up
from the ratios into the corpus load itself. ``registry_sweep.py`` already
solved this for its own walk via ``SweepFailure``; ``load_corpus`` now
returns the same real failure list instead of discarding it, and
``ProgramSnapshot`` carries a real ``parse_failures`` count so a caller
(human or the ``eds metrics`` CLI) sees "N records, M failed to parse" side
by side rather than an unexplained N."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from eds.erc import ERC
from eds.states import EvidenceState


@dataclass
class CorpusLoadFailure:
    """One real *.json file under a registry dir that failed to parse as an
    ERC record, with the real exception text — mirrors
    ``registry_sweep.SweepFailure`` so both tools report load failures the
    same shape."""

    path: str
    error: str


TESTABLE_STATES = frozenset(
    {
        EvidenceState.PROPOSED,
        EvidenceState.IMPLEMENTED,
        EvidenceState.EXECUTABLE,
        EvidenceState.OBSERVED,
        EvidenceState.VERIFIED,
        EvidenceState.REPRODUCIBLE,
        EvidenceState.REPRODUCED,
        EvidenceState.FALSIFIED,
    }
)
EXECUTABLE_OR_BETTER = frozenset(
    {
        EvidenceState.EXECUTABLE,
        EvidenceState.OBSERVED,
        EvidenceState.VERIFIED,
        EvidenceState.REPRODUCIBLE,
        EvidenceState.REPRODUCED,
    }
)


@dataclass
class ProgramSnapshot:
    total_claims: int
    executable_claim_ratio: float
    reproduction_ratio: float
    falsifier_coverage: float
    receipt_coverage: float
    state_counts: dict[str, int]
    parse_failures: list[CorpusLoadFailure] = field(default_factory=list)


def _ratio(numerator: int, denominator: int) -> float:
    if denominator == 0:
        return 0.0
    return round(numerator / denominator, 4)


def compute_snapshot(
    records: list[ERC], parse_failures: list[CorpusLoadFailure] | None = None
) -> ProgramSnapshot:
    total = len(records)
    testable = [r for r in records if r.evidence_state in TESTABLE_STATES]

    executable_or_better = sum(1 for r in records if r.evidence_state in EXECUTABLE_OR_BETTER)
    reproduced = sum(1 for r in records if r.evidence_state == EvidenceState.REPRODUCED)
    submitted_for_reproduction = sum(
        1 for r in records if r.evidence_state in {EvidenceState.REPRODUCIBLE, EvidenceState.REPRODUCED}
    )
    with_falsifier = sum(1 for r in records if r.falsifier and not r.no_falsifier)
    with_receipts = sum(1 for r in records if r.receipt_refs)

    state_counts: dict[str, int] = {}
    for r in records:
        state_counts[r.evidence_state.value] = state_counts.get(r.evidence_state.value, 0) + 1

    return ProgramSnapshot(
        total_claims=total,
        executable_claim_ratio=_ratio(executable_or_better, len(testable)),
        reproduction_ratio=_ratio(reproduced, submitted_for_reproduction),
        falsifier_coverage=_ratio(with_falsifier, len(testable)),
        receipt_coverage=_ratio(with_receipts, total),
        state_counts=state_counts,
        parse_failures=list(parse_failures or []),
    )


def load_corpus(registry_dir: Path) -> tuple[list[ERC], list[CorpusLoadFailure]]:
    """Real filesystem walk over every ``*.json`` file under ``registry_dir``.
    Returns ``(records, failures)`` — a record that fails to parse as an ERC
    is recorded in ``failures`` (real exception text) rather than silently
    dropped, so a caller can see how many files were skipped and why instead
    of an unexplained shortfall in ``total_claims``."""
    records: list[ERC] = []
    failures: list[CorpusLoadFailure] = []
    for path in sorted(Path(registry_dir).rglob("*.json")):
        try:
            records.append(ERC.read(path))
        except Exception as e:
            failures.append(CorpusLoadFailure(path=str(path), error=str(e)))
    return records, failures
