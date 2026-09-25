"""Chicago-style, no-mock tests for the state-transition graph, falsifier
execution, and independent verification added in lifecycle.py/falsifier.py/
verify.py. Zero unittest.mock/Mock/patch/monkeypatch — verified by grep as
part of this repo's own testing discipline.
"""

from __future__ import annotations

import random

import pytest

from eds.erc import ERC
from eds.falsifier import Falsifier, FalsifierResult
from eds.lifecycle import IllegalStateTransition, advance
from eds.states import EvidenceState
from eds.verify import DictSubsetVerifier


def _new_erc(**overrides) -> ERC:
    defaults = dict(
        id="erc-lifecycle-test",
        hypothesis="hybrid quicksort (insertion-sort below threshold 16) makes fewer "
        "comparisons than plain quicksort for arrays shorter than 64 elements",
        artifact_reference="tests/test_lifecycle_chicago.py::_hybrid_quicksort",
        evidence_state=EvidenceState.PROPOSED,
        falsifier="ComparisonCountFalsifier: refutes if hybrid_comparisons >= plain_comparisons",
    )
    defaults.update(overrides)
    return ERC(**defaults)


def test_illegal_transition_implemented_to_verified_raises() -> None:
    """The paper's core inequality, enforced: IMPLEMENTED -> VERIFIED must be
    a real, raised error, not two string values nobody happens to conflate."""
    erc = advance(_new_erc(), EvidenceState.IMPLEMENTED)
    assert erc.evidence_state == EvidenceState.IMPLEMENTED

    with pytest.raises(IllegalStateTransition):
        advance(erc, EvidenceState.VERIFIED, verifier=DictSubsetVerifier(), expected={}, observed={})


def test_legal_confirming_path_advances_one_step_at_a_time() -> None:
    erc = _new_erc()
    for target in (
        EvidenceState.IMPLEMENTED,
        EvidenceState.EXECUTABLE,
        EvidenceState.OBSERVED,
    ):
        erc = advance(erc, target, evidence=f"reached {target.value}")
        assert erc.evidence_state == target


def test_side_state_is_terminal_for_this_lifecycle() -> None:
    erc = advance(_new_erc(), EvidenceState.BLOCKED, evidence="no reachable environment")
    assert erc.evidence_state == EvidenceState.BLOCKED
    with pytest.raises(IllegalStateTransition):
        advance(erc, EvidenceState.IMPLEMENTED)


# --- Real, executed artifact: two real sort variants, real comparison counts ---


def _plain_quicksort(arr: list[int], counter: list[int]) -> list[int]:
    if len(arr) <= 1:
        return arr
    pivot = arr[len(arr) // 2]
    less, equal, greater = [], [], []
    for x in arr:
        counter[0] += 1
        if x < pivot:
            less.append(x)
        elif x == pivot:
            equal.append(x)
        else:
            greater.append(x)
    return _plain_quicksort(less, counter) + equal + _plain_quicksort(greater, counter)


def _hybrid_quicksort(arr: list[int], counter: list[int], threshold: int = 16) -> list[int]:
    if len(arr) <= threshold:
        # real insertion sort, real comparison counting
        arr = list(arr)
        for i in range(1, len(arr)):
            key = arr[i]
            j = i - 1
            while j >= 0:
                counter[0] += 1
                if arr[j] <= key:
                    break
                arr[j + 1] = arr[j]
                j -= 1
            arr[j + 1] = key
        return arr
    pivot = arr[len(arr) // 2]
    less, equal, greater = [], [], []
    for x in arr:
        counter[0] += 1
        if x < pivot:
            less.append(x)
        elif x == pivot:
            equal.append(x)
        else:
            greater.append(x)
    return _hybrid_quicksort(less, counter, threshold) + equal + _hybrid_quicksort(greater, counter, threshold)


class ComparisonCountFalsifier:
    """A real Falsifier: refutes the hypothesis if the hybrid variant did NOT
    make fewer comparisons than the plain variant."""

    def check(self, evidence) -> FalsifierResult:
        observed = evidence["observed"]
        hybrid_count = observed["hybrid_comparisons"]
        plain_count = observed["plain_comparisons"]
        if hybrid_count < plain_count:
            return FalsifierResult(refuted=False, rationale="hybrid made fewer comparisons, as hypothesized")
        return FalsifierResult(
            refuted=True,
            rationale=f"hybrid made {hybrid_count} comparisons, plain made {plain_count} "
            "— hypothesis did NOT hold for this input",
            counterexample_ref=str(observed.get("input_seed")),
        )


assert isinstance(ComparisonCountFalsifier(), Falsifier)  # real Protocol conformance, checked at import time


def _run_real_episode(seed: int, size: int, threshold: int) -> dict:
    rng = random.Random(seed)  # noqa: S311 - not cryptographic, seeded for real reproducibility
    arr = [rng.randint(0, 1000) for _ in range(size)]
    plain_counter = [0]
    hybrid_counter = [0]
    plain_sorted = _plain_quicksort(list(arr), plain_counter)
    hybrid_sorted = _hybrid_quicksort(list(arr), hybrid_counter, threshold=threshold)
    assert plain_sorted == hybrid_sorted == sorted(arr)  # both real implementations are correct sorts
    return {
        "input_seed": seed,
        "input_size": size,
        "plain_comparisons": plain_counter[0],
        "hybrid_comparisons": hybrid_counter[0],
    }


def test_falsifier_survives_on_a_real_favorable_seed() -> None:
    """Real execution, real counting, no mocks: for a small array, the
    real hybrid variant really does make fewer comparisons."""
    observed = _run_real_episode(seed=7, size=32, threshold=16)
    result = ComparisonCountFalsifier().check({"evidence": "", "expected": None, "observed": observed})
    assert result.refuted is False


def test_falsifier_actually_refutes_on_a_real_adversarial_case() -> None:
    """Per the paper's own §19 discipline: a falsifier that can never
    refute is not a real scientific instrument. threshold=0 forces the
    'hybrid' variant to degenerate into plain quicksort plus insertion-sort
    overhead on every recursive call, so it must lose to plain quicksort —
    proving this falsifier can genuinely trigger FALSIFIED, not just pass."""
    observed = _run_real_episode(seed=7, size=32, threshold=0)
    result = ComparisonCountFalsifier().check({"evidence": "", "expected": None, "observed": observed})
    assert result.refuted is True
    assert "did NOT hold" in result.rationale


def test_advance_to_falsified_via_real_falsifier_execution() -> None:
    """advance() actually calls the falsifier and lets a real refutation
    override the caller's requested target state."""
    erc = _new_erc(evidence_state=EvidenceState.OBSERVED)
    observed = _run_real_episode(seed=7, size=32, threshold=0)
    result = advance(
        erc,
        EvidenceState.VERIFIED,
        verifier=DictSubsetVerifier(),
        expected={},
        observed=observed,
        falsifiers=(ComparisonCountFalsifier(),),
    )
    assert result.evidence_state == EvidenceState.FALSIFIED
    assert "FALSIFIED" in result.evidence


def test_advance_to_verified_uses_real_independent_verifier() -> None:
    """The independent DictSubsetVerifier actually runs and must pass for
    real before VERIFIED is recorded — never a trusted self-report."""
    erc = _new_erc(evidence_state=EvidenceState.OBSERVED)
    observed = _run_real_episode(seed=7, size=32, threshold=16)
    expected = {"hybrid_comparisons": observed["hybrid_comparisons"]}  # a real subset check

    verified = advance(
        erc,
        EvidenceState.VERIFIED,
        verifier=DictSubsetVerifier(),
        expected=expected,
        observed=observed,
        falsifiers=(ComparisonCountFalsifier(),),
    )
    assert verified.evidence_state == EvidenceState.VERIFIED

    # Now prove the negative path is real too: an expectation the real
    # evidence does not satisfy must raise, not silently pass.
    wrong_expected = {"hybrid_comparisons": observed["hybrid_comparisons"] + 1}
    with pytest.raises(IllegalStateTransition):
        advance(
            erc,
            EvidenceState.VERIFIED,
            verifier=DictSubsetVerifier(),
            expected=wrong_expected,
            observed=observed,
        )
