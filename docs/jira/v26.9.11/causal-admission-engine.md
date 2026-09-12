# Causal Admission Engine — proof obligation before consequential DO

## Summary

Add a causal-identification admission layer that determines whether an
intervention is justified by available evidence before it becomes eligible
for actuation.

## Status

Candidate / Not Yet Implemented

(A structural slice adjacent to this scope is separately tracked as
in-progress — see Relationship to Existing Work below — but the causal
verification engine itself, described in this ticket, has not been built.)

## Scope

Required components:

- causal graph model (DAG)
- typed intervention system (RCT / IV / backdoor / frontdoor / observational_assumptions)
- back-door criterion evaluator
- front-door criterion evaluator
- instrumental-variable admission interface
- d-separation checker
- adjustment-set finder
- causal assumption registry
- placebo-test runner
- causal-admission receipt
- typed refusal for unidentified interventions
- causal falsifier registry

## Key Invariant(s)

`Selected(a) ∧ Authorized(a)` does NOT imply `Admissible(a)` when the action
depends on an empirically causal claim.

For interventions declaring a causal requirement:

`DO(a) ⟹ Identified(a)`

## Relationship to Existing Work

A real slice of this workstream (`Xaas.Actuation.Validations.CausalAdmission`,
wired into `ActuationIntent.create(:admit)`) is already in progress on branch
`codex/causal-admission-closure` / draft PR #44 in this repo. That slice
verifies only the STRUCTURE/identity of a causal certificate — it does not
itself perform causal discovery, d-separation, adjustment-set derivation, RCT
analysis, IV estimation, or placebo analysis.

This ticket's remaining scope is the actual certificate PRODUCER: the
SCM/DAG causal verifier that manufactures the evidence the admission gate
already knows how to check.

## Falsifiers / What Would Defeat This

- An intervention declaring a causal requirement (e.g. `backdoor`) is
  actuated (`DO(a)`) while `Identified(a)` is false — i.e. no valid
  adjustment set, IV, or front-door decomposition was found for the declared
  graph, and the action proceeds anyway.
- The d-separation checker or adjustment-set finder returns a set that does
  not satisfy the back-door criterion against the causal graph model for a
  known worked example (a graph with a documented correct adjustment set
  disagrees with the tool's output).
- A causal-admission receipt is produced for an intervention where no causal
  assumption was registered in the causal assumption registry — i.e. a
  receipt exists without a traceable assumption record backing it.
- An intervention with an unidentified causal claim is admitted (passes
  admission) instead of receiving the typed refusal for unidentified
  interventions.
