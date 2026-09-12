# Planning-Regime Router — dispatch admitted problems to the narrowest formal planner class

## Summary

Stop treating all decision problems as one planning class. Classify admitted
problems and dispatch each to the narrowest established formalism capable of
solving it, rather than routing everything through a single general planner
or reasoning path.

## Status

Candidate / Not Yet Implemented

## Scope

Classification -> formalism dispatch table:

- deterministic -> PDDL
- hierarchical -> HDDL / HTN
- nondeterministic -> FOND
- stochastic -> PPDDL / MDP
- partially observed -> POMDP
- constraint-heavy -> SAT / SMT / CP
- optimization -> LP / MILP / QP
- empirical-causal -> SCM / causal admission

Required components:

- problem-feature ontology
- formalism-admission predicates
- planner capability registry
- per-formalism adapters (deterministic/HDDL/FOND/stochastic/partial-observability/optimization)
- solver-result normalization
- common explanation projection
- common validation interface
- typed unsupported/refused results

## Key Invariant(s)

- The router itself performs no planning — it selects the lawful machinery.
- Dispatch is by admitted problem feature, not by default/general-purpose planner.

## Relationship to Existing Work

Not stated in the vetted source content beyond the general routing principle
(known problem class -> route to its established formal machinery rather than
re-deriving via general reasoning). No specific ticket/PR linkage was provided
as source-of-truth for this item.

## Falsifiers / What Would Defeat This

- A problem correctly classified as deterministic is routed to a
  non-PDDL/general planner despite a PDDL-capable adapter being registered and
  admitted.
- The planner capability registry reports a formalism as available but the
  corresponding adapter does not exist or cannot produce a normalized solver
  result.
- A solver-result normalization or explanation projection diverges per
  formalism such that two adapters return incompatible result shapes to the
  same common validation interface.
- An unsupported problem feature (no admitted formalism-admission predicate
  matches) is silently routed to a planner instead of returning a typed
  unsupported/refused result.
