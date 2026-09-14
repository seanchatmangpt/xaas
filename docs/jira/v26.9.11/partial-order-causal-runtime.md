# Partial-Order / Causal-Order Runtime — replace total precedence order with a partial order

## Summary

The original Constitution assumes a total order (`forall x,y: x<y or y<x or x=y`),
which discards concurrency. This workstream replaces that total order with a
partial order `(P, <=)` where independent events `a,b` satisfy `a not<= b` and
`b not<= a`. This lets Ash transitions, Reactor execution, A2A interaction, and
object-centric event history preserve actual concurrency instead of inventing
artificial serialization.

## Status

Candidate / Not Yet Implemented

## Scope

Required components:

- partial-order event model
- happens-before relation
- causal-precedence relation
- vector/logical clock adapter where applicable
- POWL projection
- OCEL projection
- concurrency detector
- race/conflict classifier
- topological linearization only when required
- order-preservation verifier
- partial-order receipt

## Key Invariant(s)

- Total order (rejected as the current, overly strong assumption):
  `forall x,y: x<y or y<x or x=y`
- Partial order (target model): `(P, <=)` where for independent events `a,b`:
  `a not<= b` and `b not<= a`

## Relationship to Existing Work

This session attempted to check for a related branch/commit
(`codex/causal-admission-closure`, commit
`38d9933efec49a8006456a7a77f61e89689eb460`) as a possible slug-linked prior
artifact. Neither the branch nor the commit was fetched locally in this repo
at the time of writing (not fetched locally, per session record). No other
relationship to existing tickets/PRs is established beyond the body content
above; this ticket does not assert or fabricate such a relationship.

## Falsifiers / What Would Defeat This

- Any Ash transition, Reactor execution, or A2A interaction pair that is
  genuinely causally independent but is still forced through a total-order
  serialization point (no partial-order event model in the path) would
  falsify the "concurrency preserved" claim.
- A concurrency detector or race/conflict classifier that misclassifies two
  causally-independent events as ordered (or vice versa, misses a real
  causal edge) would falsify correctness of the happens-before/causal-
  precedence relations.
- A topological linearization invoked where not required (i.e. used as the
  default path rather than only when an external total-order consumer
  demands it) would falsify the "linearization only when required" scope
  item.
- An order-preservation verifier that passes on a POWL or OCEL projection
  which does not round-trip the original partial order (loses or invents an
  ordering edge) would falsify the projection components' correctness.
