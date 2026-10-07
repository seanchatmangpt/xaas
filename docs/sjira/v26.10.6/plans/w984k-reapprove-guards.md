# W984k — re-approve transition guards on the 4 W982s finding-1b resources

- Lane: W984k (v26.10.6 campaign, branch `feat/playwright-surface`)
- Subject: `/Users/sac/xaas` @ `1f2a2b23` (working tree; no commit)
- Date: 2026-10-07
- Scope honored: writes = 4 resource files under `lib/xaas/billing/` +
  `test/xaas/billing/approval_lifecycle_deepening_court_test.exs` (1b/3b flip)
  + this receipt. No commit made.

## Change (per-resource before/after)

W746's proven idiom, mirrored exactly from
`lib/xaas/billing/approval_sla_credit_apply.ex:151`
(`change(filter(expr(is_nil(approved_by))))` — a DB-level WHERE-clause
filter via `Ash.Changeset.filter/2`), added as the first `change` in each
`:approve` action:

| resource | before (`:approve`) | after (`:approve`) |
|---|---|---|
| `ApprovalPricingOverride` | change(ApprovalPricingOverrideApprove) + validate(RequiresApprover); no transition guard | + `change(filter(expr(is_nil(approved_by))))` first |
| `ApprovalQuotaOverride` | validate(RequiresApprover) only; no guard | + same filter guard |
| `ApprovalInvoiceReconciliationApprove` | validate(RequiresApprover) only; no guard | + same filter guard |
| `ApprovalPatchSlaCreditApply` | change(ApprovalPatchSlaCreditApplyApprove) + validate(RequiresApprover); no guard (re-approve = double ledger credit) | + same filter guard |

Not touched: `ApprovalSlaCreditApply` (already W746-guarded),
`ApprovalTierDowngrade` (only incidentally guarded downstream — out of this
lane's scope per instruction), `Subscription` / `RevenueRecognition`
(no `:approve` action), all other resources.

## Test flip (finding pins 1b/3b → guarded-contract assertions)

In `test/xaas/billing/approval_lifecycle_deepening_court_test.exs`:

- `@db_transition_unguarded` (5 resources incl. tier_downgrade) →
  `@db_transition_guarded` (the 4 fixed resources; tier_downgrade removed
  from the iteration set — its incidental-only guard stands, unchanged).
- 1b: was "unguarded resources accept re-approval" (asserted `{:ok,
  _overwritten}` + `approved_by == "approver-b"`); now asserts typed
  zero-row refusal (`StaleRecord`/`NotFound`, Invalid class) on the second
  approve and `approved_by` still `"approver-a"` on reload, for all 4.
- 3b: was "both race tasks succeed (last-write-wins)"; now asserts exactly
  one Task.async race success, loser refused `{:refused, :invalid_zero_row}`,
  exactly one approval persisted, for all 4.

## Verification receipt (real commands, real tails)

- Build: fresh lane root `_build-laneW984k` created this session from
  scratch; compile under pinned asdf toolchain (elixir 1.20.2-otp-28).
- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984k
  mix compile` → exit 0 (pre-existing spark DSL-verify warnings only).
- `mix test test/xaas/billing/approval_lifecycle_deepening_court_test.exs`
  → `Result: 9 passed` (run 1)
- same command → `Result: 9 passed` (run 2)
- `mix test test/xaas/billing/` → `Result: 40 passed` (W982s baseline
  preserved; multitenancy/deepening siblings unaffected by the guards)
- Postgres: real local Postgres, `Ecto.Adapters.Sandbox` per test.
- Warnings: Grafana/PromEx nxdomain noise only (no Grafana locally);
  no new compile warnings from this diff.

## Race results (test 3b, real runs ×2)

All 4 resources: exactly one of the two real `:approve` tasks succeeds;
loser refused `{:refused, :invalid_zero_row}` (Ash 3.34 zero-row UPDATE →
`Ash.Error.Changes.StaleRecord`, Invalid class). For
`approval_patch_sla_credit_apply` this closes the double-credit channel:
the ledger-crediting change can no longer run twice.

## Standing

- Court: **ALIVE** — 9/9 ×2 runs, 40/40 billing dir on fresh lane root.
- W982s findings 1b (guard-absent ×4) and 3b (race double-success ×4):
  **CLOSED** — guards landed, witnesses flipped to contract assertions.
- W982s tier_downgrade PARTIAL(guard-incidental) finding: UNCHANGED,
  out of this lane's scope.
- Lane build root `_build-laneW984k` deleted at integration per fanout
  cleanup law.

## Falsifiers

- Delete any of the 4 new `change(filter(expr(is_nil(approved_by))))`
  lines → tests 1b/3b fail for that resource.
- Set `require_atomic?` or reorder so the filter is not in the UPDATE
  WHERE clause → race loser no longer refused zero-row.
