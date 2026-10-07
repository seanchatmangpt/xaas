# W540 — Art 15(5) vulnerability detect/respond/resolve lifecycle

Lane W540, EU-AI-Act wave v26.10.6. Repo `/Users/sac/xaas` @ `feat/playwright-surface`,
ONE canonical checkout, private build root `_build-laneW540`.

## Deliverable

`lib/xaas/semantics/vulnerability_lifecycle.ex` — pure state machine, four states
`:DETECTED → :TRIAGED → :RESPONDED → :RESOLVED`, forward-only one-step edges,
typed evidence required per edge, all illegal/skipping/backward transitions refused
`{:error, :REFUSED_LIFECYCLE_SKIP}` and legal-order-but-evidence-free transitions
refused `{:error, :REFUSED_LIFECYCLE_EVIDENCE}`. Deterministic, no actuation, no route.

## State → fleet-mechanism mapping (the Art 15(5) evidence)

| state | fleet mechanism | typed evidence gate | real instance |
|---|---|---|---|
| `DETECTED` | court findings: mutant-court SURVIVED findings, ExUnit failures, toolchain probes | non-empty `detector` + `finding` | w382 mutant 2 SURVIVED (empty-bearer guard `> 0` → `>= 0`, 7/7 green); w382 mutant 3 endpoint 100x body-limit; w525d `Map.update/4` absent-key deviation on otp-29 |
| `TRIAGED` | gap analysis naming the exact vacuous cell / deviation site | non-empty `analysis` | w414 gap analysis: distinguishing cell is INTERNAL_API_TOKEN **set to empty string**, not unset env as the contract predicted |
| `RESPONDED` | fix receipts: killing tests, inverse edits, contract pins | non-empty `receipt` | w414 killing test "empty bearer + empty-string env is refused 401, never authenticated" |
| `RESOLVED` | verified rerun on the original subject after revert | `green: true` + non-empty `run` | w414 full file `Result: 9 passed` under `_build-laneW414` |

This mapping structurally documents the fleet's actual process: detection = courts,
response = fixes, resolution = verified reruns. That is the Art 15(5) evidence: the
lifecycle is not asserted, it is instantiated by real receipt citations.

## Tests

`test/xaas/semantics/vulnerability_lifecycle_test.exs`:

- Worked example: w382 detection (verbatim SURVIVED tail) → w414 triage → w414 fix
  receipt → w414 verification (`Result: 9 passed`) — full path, citations preserved
  through the struct.
- Detection gate covers all three real detector classes (mutant court, ExUnit, toolchain).
- Skips (DETECTED→RESPONDED, DETECTED→RESOLVED, TRIAGED→RESOLVED), evidence-free
  legal-order calls, repeats, and backward moves → `:REFUSED_LIFECYCLE_SKIP` /
  `:REFUSED_LIFECYCLE_EVIDENCE`; state provably never regresses.
- Determinism: two identical chains compare equal; refusal outputs equal.

## Verification

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW540 \
  mix test test/xaas/semantics/vulnerability_lifecycle_test.exs
# -> <test tail recorded below>
```

## Result

ALIVE. Test tail (MIX_BUILD_ROOT=_build-laneW540, MIX_ENV=test):

```
Finished in 0.1 seconds (0.1s async, 0.00s sync)
Result: 15 passed
```

Strict compile: `mix compile --warnings-as-errors --force` → `compile_exit=0`,
`Compiling 923 files (.ex)` / `Generated xaas app`, zero warnings attributable to
`vulnerability_lifecycle.ex` (only a pre-existing non-fatal note in
`lib/ash_affidavit/signing.ex:312`, outside this lane's files).

Lane build root `_build-laneW540` deleted at close per the 2026-10-01 cleanup law.

