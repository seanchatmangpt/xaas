# Formal Proposal Coupling Engine — reconcile independently valid proposals via constrained optimization

## Summary

Replace open-ended agent negotiation for known optimization problems with formal
reconciliation of multiple independently-valid sector/planner proposals. Each
proposal is a candidate point `p_i` in the shared decision space; the engine
couples them into a single admissible plan `z` by solving a constrained
least-squares problem, weighted by each proposal's confidence and staleness,
subject to the domain's linear/affine constraints.

## Status

Candidate / Not Yet Implemented

## Scope

Required components (verbatim from the vetted proposal):

- canonical proposal representation
- constraint normalization
- confidence weighting
- staleness weighting
- QP compiler
- LP/MILP/CP alternative backends
- infeasibility explanation
- minimal unsatisfiable constraint extraction
- deterministic tie-breaking
- coupling receipt
- proposal provenance propagation

## Key Invariant(s)

Core objective (weighted least-squares proposal coupling):

```
min_z  sum_i w_i * ||z - p_i||_2^2
subject to
  A z <= b
  E z = f
  l <= z <= u
```

- `p_i` — the i-th independently-valid sector/planner proposal (a point in the
  shared decision space `z`).
- `w_i` — per-proposal weight, composed from that proposal's confidence and
  staleness (confidence weighting and staleness weighting are both required
  components above, feeding into `w_i`).
- `A z <= b`, `E z = f`, `l <= z <= u` — the normalized inequality, equality,
  and bound constraints every candidate `z` must satisfy for admissibility.

## Relationship to Existing Work

Not specified in the vetted source material beyond the framing itself: this
workstream is explicitly a replacement for open-ended agent negotiation on
known optimization problems — i.e., where a problem class is already formally
known (linear/affine constraints, quadratic objective), route it to
LP/MILP/QP/CP solvers rather than to further LLM/agent negotiation.

## Falsifiers / What Would Defeat This

- The QP compiler cannot express a real proposal set's constraints as
  `A z <= b`, `E z = f`, `l <= z <= u` without lossy approximation — i.e., the
  canonical proposal representation or constraint normalization step drops
  semantics needed for a real sector/planner input.
- The problem is infeasible (`A z <= b`, `E z = f`, `l <= z <= u` has no
  solution) and the infeasibility-explanation / minimal-unsatisfiable-
  constraint-extraction components fail to identify which constraints
  conflict, leaving the operator unable to resolve the deadlock.
- Two runs over identical proposals and weights (`p_i`, `w_i`) produce
  different `z` — i.e., deterministic tie-breaking fails to hold under
  ties or degenerate optima, breaking replay/reproducibility.
- The coupling receipt or provenance propagation cannot reconstruct, after
  the fact, which original proposal(s) and weights contributed to a given
  coordinate of the final `z` — breaking auditability of the reconciled
  plan.
