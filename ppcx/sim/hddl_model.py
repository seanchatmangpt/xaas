"""Dataclass mirror of domain/eds_cycle.hddl.

This is NOT a solver and does not parse the .hddl file. It is a small,
hand-authored runtime structure that mirrors exactly the compound
task/method/ordered-subtask shape declared in the HDDL file, so the engine
that actually walks the 9-step decomposition (sim/fond_engine.py) stays
traceable back to the formal artifact instead of drifting from it silently.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class PrimitiveAction:
    name: str
    precondition: str
    nondeterministic: bool


@dataclass(frozen=True)
class Method:
    name: str
    task: str
    ordered_subtasks: tuple[PrimitiveAction, ...]


@dataclass(frozen=True)
class Task:
    name: str
    methods: tuple[Method, ...]


# Mirrors domain/eds_cycle.hddl's (:task do-eds-cycle ...) / (:method
# eds-cycle-standard ...) exactly -- 9 ordered primitive actions, with
# nondeterministic=True marking the four (:oneof ...) effect nodes.
ONTOLOGY_ALIGN = PrimitiveAction("ontology-align", precondition="(and)", nondeterministic=False)
WORLD_OBSERVE = PrimitiveAction("world-observe", precondition="(ontology-aligned ?a)", nondeterministic=False)
INFER_HYPOTHESIS = PrimitiveAction("infer-hypothesis", precondition="(world-observed ?a)", nondeterministic=False)
PLAN_MANUFACTURE = PrimitiveAction("plan-manufacture", precondition="(hypothesis-inferred ?a)", nondeterministic=False)
FALSIFY_CHECK = PrimitiveAction("falsify-check", precondition="(plan-ready ?a)", nondeterministic=True)
ADMIT_OR_REJECT = PrimitiveAction("admit-or-reject", precondition="(survives ?a)", nondeterministic=False)
MANUFACTURE_ARTIFACT = PrimitiveAction("manufacture-artifact", precondition="(admitted ?a)", nondeterministic=True)
EXECUTE_ARTIFACT = PrimitiveAction("execute-artifact", precondition="(manufactured ?a)", nondeterministic=True)
VERIFY_RESULT = PrimitiveAction("verify-result", precondition="(executed ?a)", nondeterministic=True)

EDS_CYCLE_METHOD = Method(
    name="eds-cycle-standard",
    task="do-eds-cycle",
    ordered_subtasks=(
        ONTOLOGY_ALIGN,
        WORLD_OBSERVE,
        INFER_HYPOTHESIS,
        PLAN_MANUFACTURE,
        FALSIFY_CHECK,
        ADMIT_OR_REJECT,
        MANUFACTURE_ARTIFACT,
        EXECUTE_ARTIFACT,
        VERIFY_RESULT,
    ),
)

DO_EDS_CYCLE_TASK = Task(name="do-eds-cycle", methods=(EDS_CYCLE_METHOD,))
