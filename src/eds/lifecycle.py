"""Charter §8 upgrade: enforce the evidence-state progression as a real
transition graph, not just a static per-record field check.

``erc.py``'s ``ERC.validate()`` checks one record's internal consistency
(does a claimed state have the evidence it requires). This module adds the
orthogonal, previously-missing check the paper's core inequality demands:
``IMPLEMENTED != VERIFIED`` as an *enforced* illegal jump, not merely two
different string values that happen never to be conflated by convention.

``advance()`` is also where real falsifier/verifier execution enters the
picture (see falsifier.py / verify.py): moving to VERIFIED requires actually
calling a ``PostconditionVerifier`` against real evidence, and any transition
may instead resolve to FALSIFIED if a ``Falsifier`` finds real contradicting
evidence — this is what makes an ``ERC`` an *executable* research claim
rather than a self-reported one.
"""

from __future__ import annotations

from dataclasses import replace
from typing import Any

from eds.erc import ERC
from eds.falsifier import Falsifier
from eds.states import EvidenceState, SIDE_STATES
from eds.verify import PostconditionVerifier


class IllegalStateTransition(ValueError):
    """Raised when an ``advance()`` call would collapse two distinct
    evidence states the charter/paper require to stay distinguishable."""


# The confirming path, in order. A record may move exactly one step forward
# along this path per advance() call — no skipping a stage — or sideways into
# any SIDE_STATE (FALSIFIED/BLOCKED/UNSUPPORTED/UNKNOWN) from any point.
_CONFIRMING_PATH: tuple[EvidenceState, ...] = (
    EvidenceState.PROPOSED,
    EvidenceState.IMPLEMENTED,
    EvidenceState.EXECUTABLE,
    EvidenceState.OBSERVED,
    EvidenceState.VERIFIED,
    EvidenceState.REPRODUCIBLE,
    EvidenceState.REPRODUCED,
)


def _legal_targets(current: EvidenceState) -> frozenset[EvidenceState]:
    if current in SIDE_STATES:
        # A side state is terminal for this lifecycle: a claim that was
        # FALSIFIED/BLOCKED/UNSUPPORTED/UNKNOWN does not silently resume the
        # confirming path — a *new* ERC (with its own id/receipt lineage)
        # represents any subsequent attempt, preserving the negative result
        # as real, permanent evidence rather than overwriting it in place.
        return frozenset()
    targets: set[EvidenceState] = set(SIDE_STATES)
    idx = _CONFIRMING_PATH.index(current)
    if idx + 1 < len(_CONFIRMING_PATH):
        targets.add(_CONFIRMING_PATH[idx + 1])
    return frozenset(targets)


def legal_transition(current: EvidenceState, target: EvidenceState) -> bool:
    return target in _legal_targets(current)


def next_confirming_state(current: EvidenceState) -> EvidenceState | None:
    """Return the single next state along the confirming path from
    ``current``, or ``None`` if ``current`` is terminal (a side state, or
    already at the end of the path). Unlike ``_legal_targets`` this excludes
    the always-legal sideways SIDE_STATES so callers (e.g. registry-sweep)
    can report one concrete, actionable suggestion rather than the full legal
    target set."""
    if current in SIDE_STATES:
        return None
    idx = _CONFIRMING_PATH.index(current)
    if idx + 1 < len(_CONFIRMING_PATH):
        return _CONFIRMING_PATH[idx + 1]
    return None


def advance(
    erc: ERC,
    target: EvidenceState,
    *,
    evidence: str = "",
    verifier: PostconditionVerifier | None = None,
    expected: Any = None,
    observed: Any = None,
    falsifiers: tuple[Falsifier, ...] = (),
) -> ERC:
    """Move ``erc`` to ``target``, enforcing the legal-transition graph.

    Real execution semantics, not bookkeeping:
    - Raises ``IllegalStateTransition`` for any jump the graph forbids (e.g.
      ``IMPLEMENTED`` straight to ``VERIFIED``) — this is the literal
      enforcement of the paper's core inequality.
    - If ``falsifiers`` are given, each is actually called against
      ``evidence`` (as a ``Mapping``, e.g. ``{"expected": ..., "observed": ...}``
      or any evidence dict the caller constructs); the first real
      ``refuted=True`` result short-circuits the requested transition and
      returns a new ERC in ``FALSIFIED`` instead — the falsifier's verdict
      overrides the caller's requested target, because a real refutation is
      not something the caller may talk past.
    - If ``target`` is ``VERIFIED``, ``verifier`` must be given and is
      actually called (``verifier.judge(expected, observed)``); a failing
      judgment raises ``IllegalStateTransition`` rather than silently
      recording an unverified claim as VERIFIED.
    """
    if target not in SIDE_STATES and not legal_transition(erc.evidence_state, target):
        raise IllegalStateTransition(
            f"{erc.id}: {erc.evidence_state.value} -> {target.value} is not a legal "
            "transition (would collapse distinct evidence states)"
        )

    for falsifier in falsifiers:
        result = falsifier.check(evidence={"evidence": evidence, "expected": expected, "observed": observed})
        if result.refuted:
            return replace(
                erc,
                evidence_state=EvidenceState.FALSIFIED,
                evidence=(erc.evidence + "\n" if erc.evidence else "") + f"FALSIFIED: {result.rationale}",
            )

    if target == EvidenceState.VERIFIED:
        if verifier is None:
            raise IllegalStateTransition(
                f"{erc.id}: cannot advance to VERIFIED without a PostconditionVerifier "
                "(charter/paper: verification must be an independent judgment, not a "
                "self-report)"
            )
        passed, reason = verifier.judge(expected, observed)
        if not passed:
            raise IllegalStateTransition(
                f"{erc.id}: independent verification failed — {reason}"
            )
        evidence = evidence or reason

    new_evidence = erc.evidence
    if evidence and target in {EvidenceState.OBSERVED, EvidenceState.VERIFIED, EvidenceState.REPRODUCIBLE, EvidenceState.REPRODUCED}:
        new_evidence = (erc.evidence + "\n" if erc.evidence else "") + evidence

    return replace(erc, evidence_state=target, evidence=new_evidence)
