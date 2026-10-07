# W984dc Lane Receipt — Platform webhook delivery lifecycle depth court

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (uncommitted, coordinator-owned transitions). New file only: `test/xaas/platform/webhook_delivery_lifecycle_w984dc_test.exs` (5 tests). Incidental touch: `lib/xaas/semantics/graphlaw_wasm.ex` — one disclosed compile-freeze-SLA unblock (stranded `refuse/3` after module `end`); the owning lane (W984cy4) then converged the rest and the file now compiles clean (0 errors).
- **Census (map method)**: W984cy3 landed no receipt (`docs/sjira/v26.10.6/plans/` has only `w984cy-r2rml-probe.md`), so Ultracode was contested; took Platform-delivery. Existing coverage: W984bq policy/cloak/retry-fan-out (`platform_depth_w984bq_test.exs`), W725 signing/tamper/transition/determinism (`webhook_deepening_test.exs`), 2xx/closed-port/ceiling (`deliver_webhook_test.exs`), 50-concurrent (`webhook_delivery_stress_test.exs`). Uncovered: payload wire-byte integrity, attempt ordering + failed→delivered recovery, zero-HTTP dead-letter proof, delivery immutability under `:record_attempt`, enum typed refusal — taken as this court.
- **Court**: 5 tests, all real-state (real Bandit receiver, real Postgres sandbox, real `:deliver`/`:record_attempt`), each naming its mutant:
  1. Payload integrity: receiver raw body JSON-decodes to exactly the stored `payload` (nested maps/lists included) and equals `Jason.encode!(delivery.payload)` byte-for-byte. Kills re-serialize/drop/reorder mutants.
  2. Attempt ordering: three real dispatches (503, 503, 200) → `attempt_count` 1→2→3 strictly, `last_attempted_at` non-decreasing, status `:failed`→`:failed`→`:delivered`, exactly one receiver request per `:deliver`, durable on reload. Kills overwrite/backwards-timestamp mutants.
  3. Dead-letter: at-ceiling (`attempt_count` 5, `:failed`) `:deliver` leaves the row untouched **and receiver request count is exactly 0** — the load-bearing zero-HTTP claim the prior ceiling test (`deliver_webhook_test.exs`) never asserted. Kills burn-a-network-call mutants.
  4. Immutability: `:record_attempt` with `webhook_id`/`payload` → `Ash.Error.Invalid`, row unchanged on reload. Kills accept-list-widening mutants (replayed events must not be retargetable).
  5. Typed refusal: non-enum status `"shipped_yesterday_trust_me"` refused by real `Xaas.Platform.Types.WebhookDeliveryStatus`; fresh-row defaults `:pending`/0/nil asserted. Kills enum-loosening mutants.
- **Verification ladder (real output)**:
  - `mix compile` (MIX_ENV=test, `_build-laneW984dc`): 0 errors (after cy4 convergence).
  - `mix test test/xaas/platform/webhook_delivery_lifecycle_w984dc_test.exs` → **5 passed, 0 failed, 0 skipped** (2.1s). Pre-fix run was 3/5: both failures were `Ash.reload!/1` policy-hiding the row (this resource denies every verb under authorization — consistent with W984bq test (1)); fixed with `authorize?: false`, not a product change.
  - Mock gate on the new file: `scan_mock_usage` → `[]`.
- **Findings**: no product defects. Prior ceiling test asserted state only, never zero-HTTP; now pinned.
- **Standing**: **ALIVE** — exact subject = the uncommitted working-tree state containing the new test file; replay = the `mix test` command above under the pinned toolchain (asdf shims, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW984dc).
- **Cleanup**: `_build-laneW984dc` deleted at integration.
