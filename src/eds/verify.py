"""Charter §9/§14 upgrade: independent verification as a real, callable
object — never the artifact's own self-report.

Vendored pattern, credited: ``gymact/src/gymact/verification.py:64-169``
(2026-08 GymAct repo, same author) already implements exactly this
discipline for gym-episode verification: "GymAct never treats a provider's
own ``Environment.verify()`` report as the verdict... an actor must not also
be the judge of its own outcome." This module lifts the same
``PostconditionVerifier`` Protocol + ``DictSubsetVerifier`` shape into a
gym-independent, dependency-free form so EDS's own ``ERC.verification``
field can be backed by a real judgment call instead of free text.

This is a deliberate small vendor, not a dependency on ``gymact`` — a
general research-methodology package should not depend backwards on one
specific lab's execution kernel (gymact should eventually depend on ``eds``,
not the reverse).
"""

from __future__ import annotations

from typing import Any, Mapping, Protocol, runtime_checkable


@runtime_checkable
class PostconditionVerifier(Protocol):
    """Judges ``observed`` against ``expected`` independently of whatever
    self-report the artifact under test produced. Returns ``(passed, reason)``
    — ``reason`` must be a real, human-checkable explanation, not a bare bool."""

    def judge(self, expected: Any, observed: Any) -> tuple[bool, str]: ...


class DictSubsetVerifier:
    """Default judge: recursively checks that every key/value pair in
    ``expected`` is present and equal in ``observed``. Extra keys in
    ``observed`` are permitted (an artifact may report more than was asked);
    missing or mismatched expected keys fail the judgment."""

    def judge(self, expected: Any, observed: Any) -> tuple[bool, str]:
        if not isinstance(expected, Mapping):
            passed = expected == observed
            return passed, "" if passed else f"expected {expected!r}, observed {observed!r}"
        if not isinstance(observed, Mapping):
            return False, f"expected a mapping-shaped observation, got {type(observed).__name__}"
        for key, expected_value in expected.items():
            if key not in observed:
                return False, f"missing key {key!r} in observed evidence"
            sub_passed, sub_reason = self.judge(expected_value, observed[key])
            if not sub_passed:
                return False, f"key {key!r}: {sub_reason}"
        return True, ""
