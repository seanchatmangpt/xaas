"""Charter §7/§9 upgrade: falsifiers as first-class, executable, callable
objects — not just the descriptive text ``ERC.falsifier`` currently holds.

The paper's requirement (Executable Design Science, §9): "A system incapable
of producing output contradicting its own thesis is not a strong scientific
instrument." A free-text falsifier description satisfies the *charter's*
record-shape check (``ERC.validate()``), but it cannot actually be run to
produce a real refutation verdict. This module closes that gap: a
``Falsifier`` is a real callable that inspects real evidence and can return
``refuted=True`` for real.

Pattern credit: shaped after ``gymact/src/gymact/verification.py``'s
``PostconditionVerifier`` Protocol (an independent, artifact-external judge,
``@runtime_checkable``, zero framework dependency) — see verify.py for the
sibling verifier abstraction this mirrors.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping, Protocol, runtime_checkable


@dataclass(frozen=True)
class FalsifierResult:
    """The real outcome of running one falsifier against real evidence.

    ``refuted=True`` means the falsifier found the hypothesis's own claim to
    be weakened or contradicted by the evidence — this is a first-class,
    expected, useful outcome (charter/paper §19's F1-F6 discipline), not a
    failure of the falsifier itself.
    """

    refuted: bool
    rationale: str
    counterexample_ref: str | None = None


@runtime_checkable
class Falsifier(Protocol):
    """A real, executable object that can weaken or refute a hypothesis.

    ``check`` must be a pure function of ``evidence`` — it must not itself
    re-execute the artifact or trust the artifact's own self-report. Feed it
    independently observed evidence (e.g. from ``ERC.evidence`` /
    ``Receipt.outputs``), never the artifact's own "I passed" claim.
    """

    def check(self, evidence: Mapping[str, Any]) -> FalsifierResult: ...
