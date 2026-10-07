# W984u — billing surface landed-uncommitted integration (2 atomic commits)

- Lane: W984u (v26.10.6 campaign, branch `feat/playwright-surface`)
- Repo: `/Users/sac/xaas`
- Date: 2026-10-07
- Authority: coordinator-delegated commit (no push).

## Owner-lane preconditions (all satisfied before any commit)

- W984k (re-approve guards ×4 + court flip): receipt
  `w984k-reapprove-guards.md` — initially absent; polled ~12 min, landed.
  Committed in this lane's commit 1/2.
- W982r (score_book Decimal fix): receipt `w982r-nextread-cluster.md`
  present at lane start. Committed in commit 1/2.
- W984b (checkout_policy test-contract update): receipt
  `w984b-checkout-leak.md` present at lane start. Committed in commit 2/2.

## Commits (explicit pathspec, `git commit -F <file> -- <paths>`)

1. `32487e08` — fix(billing): W984k re-approve guards on 4 approval
   resources + W982r score_book Decimal fix
   - `lib/xaas/billing/approval_pricing_override.ex`
   - `lib/xaas/billing/approval_quota_override.ex`
   - `lib/xaas/billing/approval_invoice_reconciliation_approve.ex`
   - `lib/xaas/billing/approval_patch_sla_credit_apply.ex`
   - `lib/xaas/library/reactors/steps/score_book.ex`
2. `d7beb066` — test(billing): flip approval lifecycle court legs +
   checkout policy test-contract update
   - `test/xaas/billing/approval_lifecycle_deepening_court_test.exs`
   - `test/xaas/library/checkout_policy_deepening_test.exs`

## Gate (real commands, pinned asdf toolchain elixir 1.20.2-otp-28)

- `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984u rm -rf <root> &&
  mix compile --force` → EXIT=0 fresh root (942 xaas files, "Generated
  xaas app").
- `mix test test/xaas/billing/
  test/xaas/library/checkout_policy_deepening_test.exs` →
  `Result: 53 passed` ×1 (after first two launch attempts hit a transient
  `ash_graphql.app` load failure under heavy concurrent lane load;
  resolved after a bare `mix test test/test_helper.exs` warm pass — 0
  tests, harness OK. Third run green. No code change between attempts.)

## Exclusions (not committed by this lane; left in working tree)

- All other modified/untracked paths in `git status` (~41 remaining
  modified files: docs, lib/xaas/{a2a,conference,coupling,governance,
  ledger,ocel,security,...}, other test dirs) — owned by other lanes or
  the coordinator. Only the 7 staged paths above were committed.
- At receipt-commit time, `approval_sla_credit_apply.ex`,
  `approval_tier_downgrade.ex`, `subscription.ex` appeared modified in
  `lib/xaas/billing/` (post-enumeration, another lane in flight) —
  NOT staged or committed by this lane.

## Standing

- Court: **ALIVE** — fresh-root compile EXIT=0 + 53/53 gated tests on the
  exact committed subject (post-commit tree == gated tree for the 7
  paths).
- W982s findings 1b/3b: CLOSED (via W984k guards, now committed).
- score_book Decimal next-read fix (W982r): landed.
- checkout policy test contract (W984b): landed.
- Lane build root `_build-laneW984u` deleted at integration per fanout
  cleanup law.

## Falsifiers

- Revert `32487e08` → tests 1b/3b in
  `approval_lifecycle_deepening_court_test.exs` fail for all 4 resources.
- Revert only the score_book hunk → W982r falsifier
  (`w982r-nextread-cluster.md`) fires.
- Revert only `checkout_policy_deepening_test.exs` → W984b
  (`w984b-checkout-leak.md`) contract assertions fail.
