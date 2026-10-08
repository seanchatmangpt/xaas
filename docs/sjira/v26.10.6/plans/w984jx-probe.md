# W984jx — unclaimed-family probe: `Xaas.Billing.Subscription` action layer

Lane: W984jx · Repo: /Users/sac/xaas @ feat/playwright-surface (145b5659 at start)
Date: 2026-10-08 · Commit: none (per dispatch)

## Scope

`lib/xaas/billing/subscription.ex` own action layer, EXCLUDING the
change_tier/atomic-retrofit sites already courted by W984cc/fr/DD
(not restated).

## Census → dispositions

| Surface | Disposition | Court |
|---|---|---|
| `:create` happy path, defaults (:standard/:incomplete, nil sub id / period end) | COVERED | billing_deepening_test.exs:76 |
| `:create` `unique_org` identity | COVERED | subscription_test.exs:332, billing_deepening_test.exs:138 |
| `:create` full Stripe identity round-trip (nullable `stripe_subscription_id` + typed `current_period_end`) | UNCOVERED → courted | w984jx test 1 |
| `:create` `allow_nil?(false)` floor on `stripe_customer_id` (typed refusal + no row) | UNCOVERED → courted | w984jx test 2 |
| `sync_from_stripe` status state machine — all admitted edges, self-edges, refusals, terminal-is-terminal | COVERED | w984dp court, billing_deepening_test.exs:89-186 |
| `sync_from_stripe` activation charge + replay idempotency | COVERED | subscription_test.exs, w984dd court |
| `sync_from_stripe` non-status accepted fields (`stripe_subscription_id`, `current_period_end`) — the applyStripeEvent / replacement-subscription write surface | UNCOVERED → courted | w984jx test 3 (no test in repo passed either field to this action; every existing court passes only `%{status: ...}`) |
| `change_tier` proration math, direction, expired-period clamp, no-op refusal, ledger-failure rollback | COVERED | w984dd court, subscription_test.exs, w984fr/atomic_retrofit_court |
| `change_tier` argument `one_of` constraint (out-of-family tier refused before any validation/change) | UNCOVERED → courted | w984jx test 4 |
| AshIam read floor (allow / no-policy deny / resource-scoped deny) | COVERED | subscription_test.exs:130-179 |
| Attribute multitenancy on :org_id | COVERED | billing_multitenancy_court_test.exs |

## Court

`test/xaas/billing/subscription_resource_court_w984jx_test.exs` — 4 tests,
real sandboxed Postgres, real Ash actions, zero mocks, per-test mutation
rationale inline. Each test names the exact mutation that flips it RED
(accept-list deletion, allow_nil relaxation, one_of widening).

## Gates (real output)

- `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984jx mix test test/xaas/billing/subscription_resource_court_w984jx_test.exs` → `4 passed` (exit 0)
- `... mix test test/xaas/billing/` → run 1: 80/81 (1 failure in
  approval_pricing_override_approve_w984dv_test.exs — the documented
  AshEvents global advisory-lock serialization flake, file outside this
  lane's scope); run 2 (rerun, no changes): `81 passed`. Siblings green.
- Mock gate: `scan_mock_usage(["test","lib"])` → `[]`

## Notes

- One mid-court fix during the run: `Ash.Changeset.get_attribute(:status)`
  defaults the unprovided status to the data value on update changesets,
  so a fields-only sync admits via the self-edge — no resource change
  needed; probe receipts in lane transcript.
- Build-root cleanup: see below.

## Cleanup

Tried `rm -rf _build-laneW984jx` post-gates → REMOVED (verified GONE).
