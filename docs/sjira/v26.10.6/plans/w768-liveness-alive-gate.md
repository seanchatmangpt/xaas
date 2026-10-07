# W768 — Capability-liveness ALIVE gate (W750 G1)

- **Lane**: W768, xaas v26.10.6, branch `feat/playwright-surface` @ `a0723bf6`
- **Scope**: closes W750's typed gap G1 only — no TTL/regression-detection changes (G2 explicitly out of scope, still pinned by the untouched W750 tests).
- **Standing**: ALIVE — observed execution: all listed suites ran green under the lane build root on the exact subject.

## Diff (3 files)

1. `lib/xaas/operations/validations/capability_liveness_receipt_status_gate.ex` (new) — house
   validation-module idiom (`lib/xaas/operations/validations/*`, e.g. `IncidentResolvedRequiresResolvedAt`),
   a real `Ash.Resource.Validation` wired into `:ingest` only. Two typed rules:
   - `status` must be in the standing vocabulary actually consumed by the real consumers:
     ALIVE / REFUTED / BLOCKED / UNKNOWN / PARTIAL / PARTIAL_ALIVE / UNSUPPORTED / BUILD_BROKEN.
     Vocabulary grounded by grep: regression detector keys on `"ALIVE"` vs non-`"ALIVE"`
     (`capability_liveness_regressions.ex:44`); existing suites exercise ALIVE/REFUTED/BLOCKED
     (`capability_liveness_receipt_test.exs`), PARTIAL (`capability_liveness_receipt_test.exs:77`),
     UNSUPPORTED/BUILD_BROKEN (`capability_liveness_regressions_property_test.exs:53`).
     Fabricated strings refuse typed `INVALID_STATUS_VOCABULARY`.
   - `status == "ALIVE"` requires `executed == true`; otherwise typed refusal
     `ALIVE_WITHOUT_EXECUTION` ("ALIVE requires observed execution").
   - Not a data-layer enum migration: admission-boundary enforcement only; historical rows,
     read paths, and `detect/1` (ALIVE vs non-ALIVE) untouched.
2. `lib/xaas/operations/capability_liveness_receipt.ex` — `:ingest` gains
   `validate {Xaas.Operations.Validations.CapabilityLivenessReceiptStatusGate, []}`. No other change
   (policies, upsert identity, defaults — including `executed` default `true` — unchanged).
3. `test/xaas/operations/capability_liveness_deepening_test.exs` (extend-only) — W750's two
   gap-pinning tests replaced by typed-refusal courts:
   - ALIVE + executed:false → raises `Ash.Error.Invalid` matching `ALIVE_WITHOUT_EXECUTION`,
     zero rows persisted.
   - fabricated status → raises matching `INVALID_STATUS_VOCABULARY`, zero rows persisted.
   - non-ALIVE statuses (REFUTED/BLOCKED/UNKNOWN) with executed:false ingest unaffected.
   - all other W750 courts kept verbatim (round trip, 401, TTL gap pin, upsert semantics,
     regression firing, determinism).

## Verification (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW768 \
  mix test test/xaas/operations/capability_liveness_deepening_test.exs
# => 9 passed (0.9s)

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW768 \
  mix test test/xaas/operations/capability_liveness_receipt_test.exs \
    test/xaas/operations/capability_liveness_receipt_stress_test.exs \
    test/xaas/operations/capability_liveness_receipt_check_regressions_test.exs \
    test/xaas_web/controllers/capability_regressions_controller_test.exs \
    test/xaas_web/internal_api_router_test.exs \
    test/xaas/operations/capability_liveness_deepening_test.exs
# => 24 passed, 1 excluded (property test, by tag — unchanged, still tag-gated)
```

## Mutation rationale

Dropping the validation (reverting diff item 2) makes both refusal courts fail immediately:
"ALIVE with executed:false refuses typed and persists no row" fails at its `assert_raise`
(an ungated ingest succeeds, returning a receipt instead of raising), and the vocabulary court
fails identically on `INVALID_STATUS_VOCABULARY`. The no-row-persisted asserts then also fail
against the leaked persisted row. So the courts are non-vacuous: any regression of the gate is
a visible red, not a silent pass.

## Typed notes

- First run failed 9/9 with `validate/2` undefined — Ash 3.34's `Ash.Resource.Validation`
  callback is `validate/3` (changeset, opts, context). Fixed forward; fixed in the validation
  module only, no test weakened.
- Not done (out of scope): W750 G2 (upsert-history-blind regression detection / TTL).
- Lane lease honored: `_build-laneW768` deleted after final green run; no commits made.
