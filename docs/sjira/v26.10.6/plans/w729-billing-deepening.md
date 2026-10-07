# W729 — Billing domain deepening (receipt)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` HEAD `a0723bf6` (uncommitted lane files per coordinator instruction: no commit)
- **Lane**: W729, v26.10.6 campaign
- **Deliverable**: `test/xaas/billing_deepening_test.exs` (new, 13 tests) + this receipt. No other files touched.

## O/O*

- Task direction from coordinator (O*): undocketed `Xaas.Billing` domain (8 resources) gets
  Chicago-style deepening tests across (a) subscription lifecycle + typed refusals,
  (b) maker-checker, (c) multitenancy scoping, (d) atomic quantity invariants.
- Read before writing: `lib/xaas/billing.ex`, `lib/xaas/billing/subscription.ex`,
  `lib/xaas/billing/approval_pricing_override.ex`, `lib/xaas/billing/approval_sla_credit_apply.ex`,
  `lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex`,
  `lib/xaas/billing/changes/subscription_prorate_tier_change.ex`,
  `lib/xaas/billing/validations/*`, existing `test/xaas/billing/*` (conventions:
  `async: false`, Sandbox checkout, `real_balance_for/1` max-transfer_id read).

## μ / diff

- 1 new file: `test/xaas/billing_deepening_test.exs` — handwritten (no generator profile for
  test authoring in this repo; explicit handwritten residue).
- 100% real collaborators: real Postgres via `Ecto.Adapters.SQL.Sandbox`, real Ash actions
  (`Ash.Changeset.for_create/for_update` + `Ash.create!/update!`), real `Xaas.Ledger`
  Account/Transfer/Balance rows asserted on read-back. Zero mocks (mock gate clean by
  construction: no `patch(`/`Mock` in file).

## Verification (real commands, real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW729 \
  mix test test/xaas/billing_deepening_test.exs
# → Finished in 2.0 seconds (0.00s async, 1.8–2.0s sync)
#   Result: 13 passed   (final run; intermediate runs: 10/12 → 11/12 → 13 passed)
```

## What the tests pin (all real, asserted row state)

(a) Subscription lifecycle: `:create` defaults `:standard`/`:incomplete`; `:sync_from_stripe`
`incomplete→active` charges the real $29.00 activation fee (Ledger balance −$29.00 read back);
`→past_due→canceled` persists; out-of-enum status refused (`Ash.Error.Invalid`, row untouched);
`unique_org` identity refuses a second org row; `:change_tier` no-op refused.

(b) Maker-checker on `ApprovalPricingOverride`: request → approve by a different actor persists
`approved_by`; self-approval refused with the real validation message ("cannot approve their own
pricing override request") and no row mutation; missing approver refused.

(c) Multitenancy: **TYPED GAP — nothing to assert.** None of the 8 `Xaas.Billing` resources
declares a `multitenancy do` block (`lib/xaas/billing/subscription.ex` itself names this as
disclosed follow-up). No fake multitenancy test written.

(d) Atomic quantity: SLA-credit `:approve` credits exactly `credit_amount_cents / 100` dollars
(ex_money `Money.new/2` integer = major units — my first two assertions used the wrong unit and
were corrected against the real code contract); fresh-record repeat `:approve` is idempotent.

## Typed gaps / findings

1. `UNSUPPORTED(lifecycle-state-machine)` — pinned by a test: `:sync_from_stripe` accepts any
   in-enum status from any prior status (`:canceled → :active` accepted). No transition guard
   exists. Test pins current behavior so a future guard cannot land silently.
2. **`UNSUPPORTED(db-level-approve-idempotency)` — real finding**: the SLA-credit
   `newly_approved?/2` guard reads the caller's in-memory `changeset.data.approved_by`, not the
   database. A repeat `:approve` through a stale record really double-credits the org's Ledger
   account (pinned by test). No identity/unique-constraint/atomic_update backstop exists. This
   is the same bug class the `after_action/2` fix closed for failure-atomicity — recommend a
   DB-level guard as follow-up (docketed here, not fixed in this lane).
3. `UNSUPPORTED(multitenancy)` — no `multitenancy do` on any billing resource; org scoping
   exists only as a loose `org_id` string + policy checks (`SlaCreditActorOrgMatches`).
4. `UNSUPPORTED(atomic_update)` — no `atomic_update` in the billing tree; atomicity discipline
   is `after_action/2` same-transaction Ledger writes.

## Standing

- **PARTIAL_ALIVE**: 13/13 real sandbox-backed assertions pass on the exact subject; domain
  behavior is witnessed, with the four typed gaps above remaining UNKNOWN→docketed follow-ups.
- Replay: checkout at `a0723bf6`, `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test
  test/xaas/billing_deepening_test.exs`.

## Cleanup

`_build-laneW729` (~364 MB) left in place — `rm -rf` was denied by the session permission
system. Coordinator should delete it at integration per the lane-lease cleanup law.
