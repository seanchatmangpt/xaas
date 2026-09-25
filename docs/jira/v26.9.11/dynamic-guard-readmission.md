# Dynamic Guard Re-Admission — re-check guards at every semantic state transition, not just ingress

## Summary

Guards (conservation, budget, chronology, lead-time, legality) must not be
ingress-only. Because `O_t != O_{t+n}`, a previously valid action may become
unlawful later (budget consumed, authority expired, resource gone, regulation
changed, concurrent state changed). This ticket documents the required
redesign of the guard lifecycle from a single ingress check to re-admission
at every semantic state transition.

## Status

Candidate / Not Yet Implemented

## Scope

New guard lifecycle:

```
IngressAdmission -> PlanningAdmission -> PreDOAdmission -> PostconditionValidation
```

Required components:

- canonical guard ontology
- guard dependency graph
- per-stage guard evaluators (ingress/planning/pre-actuation/consequence)
- guard version identity
- stale-guard detection
- policy-expiration detection
- authority-expiration detection
- chronology/budget/conservation/legality guards
- typed refusal receipts

## Key Invariant(s)

- `O_t != O_{t+n}` — the observed world state at admission time is not
  guaranteed to equal the world state at any later execution stage.
- A guard result is only valid for the state it was evaluated against; a
  guard passed at `IngressAdmission` does not imply the same guard would
  pass at `PlanningAdmission`, `PreDOAdmission`, or `PostconditionValidation`.

## Relationship to Existing Work

Not fetched locally, per session record — no linked branch/PR/commit was
verified in this repo for this workstream. The body content above (guard
lifecycle stages and required components) is the source of truth for this
ticket; no additional existing-work relationship is asserted beyond what is
stated here.

## Falsifiers / What Would Defeat This

- An action admitted at `IngressAdmission` is actuated at `PreDOAdmission`
  without any guard evaluator re-running against current state, and it
  succeeds despite the underlying resource/budget/authority having changed
  in the interim — proves re-admission is not actually enforced.
- A stale guard (superseded by a new guard version) is still evaluated and
  its pass/fail result is accepted without stale-guard detection flagging it.
- An expired authority or expired policy is used to admit an action at any
  stage without authority-expiration or policy-expiration detection
  refusing it.
- A refusal at any stage produces no typed refusal receipt (or an untyped/
  generic one), breaking the requirement that refusals be typed and
  receipted.
