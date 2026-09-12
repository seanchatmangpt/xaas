# Ash-Native Knowledge Hooks — semantic observers bounded to OBSERVE→SELECT→CONSTRUCT

## Summary

Knowledge Hooks must remain semantic observers over native Ash application
transitions — never another workflow/callback runtime. They must NOT: register
runtime callbacks, schedule timers, mutate files, execute arbitrary functions,
bypass authority, or actuate downstream systems directly. This ticket tracks
the bounded set of Ash-native observer/projection/admission components needed
to keep Knowledge Hooks within an OBSERVE→SELECT→CONSTRUCT boundary, with
actuation (DO) remaining out of scope for this component set.

## Status

Candidate / Not Yet Implemented

## Scope

Required components (verbatim from source material):

- Ash action observer
- Ash changeset projection
- Ash notification adapter
- AshStateMachine transition projection
- Reactor outcome projection
- AshOban delivery-state projection
- Semantic delta constructor
- SPARQL predicate evaluator
- Result-delta predicate evaluator
- Knowledge-hook admission result
- Candidate-intent constructor
- Explicit unsupported-predicate refusal
- Unobserved-trigger refusal
- External-trigger evidence binding

## Key Invariant(s)

- Knowledge Hooks are bounded to `OBSERVE → SELECT → CONSTRUCT`; they do not
  extend into `DO`/actuation.
- Knowledge Hooks must NOT: register runtime callbacks, schedule timers,
  mutate files, execute arbitrary functions, bypass authority, or actuate
  downstream systems directly.
- Every hook outcome resolves to one of: a `knowledge-hook admission result`,
  a `candidate-intent constructor` output, or an explicit refusal
  (`explicit unsupported-predicate refusal` / `unobserved-trigger refusal`) —
  no silent fallthrough.
- External triggers require `external-trigger evidence binding` — a trigger
  without bound evidence is not an admissible observation.

## Relationship to Existing Work

Source material provided for this ticket did not state an explicit
relationship to other tickets/PRs in this repo; none is asserted here beyond
the scope and invariants given.

## Falsifiers / What Would Defeat This

- A Knowledge Hook is found registering a runtime callback, timer, or
  executing an arbitrary function outside the projection/evaluator components
  listed in Scope — defeats the "semantic observer, not another
  workflow/callback runtime" boundary.
- A hook path actuates a downstream system directly (e.g. triggers a Reactor
  step, AshOban job, or external side effect) without passing through a
  `candidate-intent constructor` and a separate, authorized DO path — defeats
  the OBSERVE→SELECT→CONSTRUCT boundary.
- A SPARQL or result-delta predicate that is not recognized/supported is
  evaluated as if admitted (no `explicit unsupported-predicate refusal`
  emitted) — defeats the required-refusal invariant.
- An external trigger is accepted and admitted without a corresponding
  `external-trigger evidence binding` — defeats the evidence-binding
  invariant.
