# Consequence Verification Boundary — reject CommandSucceeded ⇒ GoalAchieved

## Summary

Execution produces an EXPECTED state transition; observation determines whether it
actually occurred. Final execution status must be produced by an independent
verifier, not the actuator. This ticket tracks the backlog workstream to build a
consequence-verification boundary that rejects the implicit inference
`CommandSucceeded ⇒ GoalAchieved` and replaces it with an independently observed and
compared postcondition.

## Status

Candidate / Not Yet Implemented

## Scope

Required components (verbatim from the vetted body content):

- expected-postcondition representation
- consequence observer
- postcondition query generation
- delta comparator
- timeout semantics
- asynchronous-pending state
- partial-consequence state
- unexpected-consequence classifier
- duplicate/retry consequence detection
- independent verifier interface
- consequence receipt

## Key Invariant(s)

- `CommandSucceeded ⇏ GoalAchieved` — a command/actuator reporting success is not
  itself proof that the intended goal state was reached.
- Final execution status must be produced by an **independent verifier**, not the
  actuator that performed the action.
- Execution produces an *expected* state transition; observation determines whether
  it *actually occurred* — these are two distinct steps, not one.

## Relationship to Existing Work

No relationship to other tickets/PRs is stated in the vetted body content for this
workstream, so none is asserted here. (The task's conditional check for
`codex/causal-admission-closure` / commit `38d9933efec49a8006456a7a77f61e89689eb460`
applies only to a differently-slugged ticket — "causal-admission-pr44-ci-transport-fix"
— not to this one, so it was not run.)

## Falsifiers / What Would Defeat This

- A verifier implementation exists but is *not independent* of the actuator (e.g. it
  reads the actuator's own self-reported exit code as its sole evidence source) —
  this would defeat the core invariant even if every listed component is present.
- The system ships without a **delta comparator** — i.e. it observes post-state but
  never compares it against the expected-postcondition representation — meaning
  `CommandSucceeded ⇒ GoalAchieved` is still implicitly assumed downstream.
- Asynchronous or long-running actions have no **asynchronous-pending state** or
  **timeout semantics**, causing the verifier to block indefinitely or to falsely
  report success/failure before the true consequence is observable.
- Retried or duplicated actions are recorded as independent consequences (no
  **duplicate/retry consequence detection**), producing a **consequence receipt**
  that overcounts or misattributes state changes.
