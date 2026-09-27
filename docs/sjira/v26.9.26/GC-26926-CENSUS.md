# GC-26926-CENSUS — Capital Census: residual-only dispatch

- **standing:** UNKNOWN (directive recorded 2026-09-26, design below, no implementation yet)
- **source:** operator cross-conversation synthesis, 2026-09-26 evening
- **owner:** xaas (control plane) + ggen-marketplace (census catalog); zcode-cli stays disposable constructor

## The order

ZCode should not receive the original task first. The fleet computes what it
already knows how to do and gives ZCode only the irreducible residual.

```
WorkOrder → Bind → CapitalCensus → Applicability → Closure → ResidualGap
          → Route → Execute → Verify → Experience → Promote
```

K = packs ∪ ontologies ∪ receipts ∪ machine experience ∪ verifiers ∪
falsifiers ∪ generators ∪ docs/twins ∪ qualified implementations.
`Gap = Required − Closure(K | O*)`; `Gap = ∅ ⇒ LLM reasoning = 0`.
Route lattice: Reuse ≺ Compose ≺ Rule ≺ Plan ≺ Constraint ≺ Generate ≺
SpecializedModel ≺ LLM.

## Acceptance (first slice)

1. gall-work claim payload carries an `admitted_capital` +
   `residual_gap` + `falsifier` block (XaaS-computed, worker-consumed).
2. A census run over one real work order produces a CapitalReceipt
   `{O*, Required, Candidates, Admitted, Rejected, Unknown, Closure,
   Residual, Route}` with the distinctions found ≠ applicable ≠ admitted ≠
   sufficient ≠ authorized and UNKNOWN first-class.
3. A repeat work order in the same class demonstrates `I(W₂) < I(W₁)`:
   the second cycle consumes the first cycle's promoted capital (measured
   as fewer LLM reasoning hops, not just success).
4. IEC-011 inverse-index law lands as a query: `IEC_{n+1} = IEC_n −
   Promoted(Capital_n)`.

## Machine experience law

Experience = (State, Action, Observation, Outcome, Evidence) tuples; 
`RepeatedFailureReasoning > 1 ⇒ SystemDefect`. First witnessed instance:
the 2026-09-26 burn-in NULL-worktree / gate-refusal failure, promoted
same-day (xaas f344fa4, 03fafc2, a6699cc + regression tests).

## History

| ts | standing | note |
|---|---|---|
| 2026-09-26T23:20Z | UNKNOWN | seeded from operator directive; burn-in wave in flight (driver pid 70127) |
