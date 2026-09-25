"""A real, hand-written, seeded Monte Carlo FOND-HTN *execution simulator*.

This is explicitly NOT a solver. It does not search for a plan or compute
policies over a state space the way a real FOND-HTN planner (e.g. one built
on PRP/FIP-style approaches) would. It is a deterministic-given-seed executor
that walks the fixed 9-step method from sim/hddl_model.py in order and, at
each nondeterministic action (the four HDDL :oneof nodes), draws a real
sample from a real per-action, per-cycle random.Random instance to decide
which branch of the outcome actually happened -- real branching on
nondeterministic outcomes, not a pre-scripted straight-line path.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import random

from ppcx.sim.hddl_model import EDS_CYCLE_METHOD, PrimitiveAction

# Real multi-outcome distribution per nondeterministic action, matching the
# domain's :oneof effects. Values are (outcome_name, probability) tuples;
# probabilities within one action must sum to 1.0.
ACTION_OUTCOMES: dict[str, tuple[tuple[str, float], ...]] = {
    "falsify-check": (("survives", 0.85), ("falsified", 0.15)),
    "manufacture-artifact": (
        ("manufactured", 0.65),
        ("blocked", 0.20),
        ("unsupported", 0.15),
    ),
    "execute-artifact": (("executed", 0.90), ("blocked", 0.10)),
    "verify-result": (("verified", 0.85), ("falsified", 0.15)),
}

# Outcomes that are terminal-negative for the cycle -- reaching one of these
# short-circuits the remaining ordered subtasks (real branching).
_TERMINAL_NEGATIVE = frozenset({"falsified", "blocked", "unsupported"})


def _sample(rng: random.Random, outcomes: tuple[tuple[str, float], ...]) -> tuple[str, float]:
    names = [name for name, _ in outcomes]
    weights = [w for _, w in outcomes]
    draw = rng.random()
    cumulative = 0.0
    for name, weight in zip(names, weights):
        cumulative += weight
        if draw < cumulative:
            return name, draw
    return names[-1], draw


@dataclass
class ActionDraw:
    action: str
    outcome: str
    random_value: float


@dataclass
class CycleTrace:
    """The real, executed result of one FOND-HTN cycle walk."""

    actions_run: list[str] = field(default_factory=list)
    draws: list[ActionDraw] = field(default_factory=list)
    skipped: list[tuple[str, str]] = field(default_factory=list)  # (action, reason)
    terminal_status: str = "verified"

    def draw_for(self, action: str) -> ActionDraw | None:
        for d in self.draws:
            if d.action == action:
                return d
        return None


def run_cycle(cycle_no: int, master_seed: int, method=EDS_CYCLE_METHOD) -> CycleTrace:
    """Walk the ordered subtask list for real, drawing a fresh
    random.Random per action from a deterministic, reproducible seed tuple.
    """
    trace = CycleTrace()
    short_circuited = False
    for action in method.ordered_subtasks:  # type: PrimitiveAction
        if short_circuited:
            trace.skipped.append((action.name, "upstream short-circuit"))
            continue

        if not action.nondeterministic:
            trace.actions_run.append(action.name)
            continue

        rng = random.Random(f"{master_seed}:{cycle_no}:{action.name}")
        outcomes = ACTION_OUTCOMES[action.name]
        outcome, draw_value = _sample(rng, outcomes)
        trace.actions_run.append(action.name)
        trace.draws.append(ActionDraw(action=action.name, outcome=outcome, random_value=draw_value))

        if outcome in _TERMINAL_NEGATIVE:
            trace.terminal_status = outcome
            short_circuited = True
            continue

        trace.terminal_status = outcome

    return trace


def force_positive_cycle(method=EDS_CYCLE_METHOD) -> CycleTrace:
    """Historical cycles are grounded to the real paper history, not
    sampled: every action is forced to its positive branch."""
    trace = CycleTrace()
    for action in method.ordered_subtasks:
        trace.actions_run.append(action.name)
        if action.nondeterministic:
            positive = {
                "falsify-check": "survives",
                "manufacture-artifact": "manufactured",
                "execute-artifact": "executed",
                "verify-result": "verified",
            }[action.name]
            trace.draws.append(ActionDraw(action=action.name, outcome=positive, random_value=-1.0))
            trace.terminal_status = positive
    return trace
