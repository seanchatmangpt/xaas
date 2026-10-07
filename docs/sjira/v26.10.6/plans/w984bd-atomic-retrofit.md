# W984bd — W729/SPEC-08 atomic_update retrofit: BLOCKED(billing-tree-hot), plan carried forward + per-site classification staged

- Lane W984bd, xaas v26.10.6, repo `/Users/sac/xaas`,
  branch `feat/playwright-surface` (dirty campaign tree; **no commit made** —
  coordinator owns commits).
- **Zero files written outside this receipt.** Billing tree untouched
  (one-writer law); no court test created; no `_build-laneW984bd` created
  (no mix runs this lane).

## Standing: BLOCKED(billing-tree-hot)

### Fresh evidence (this lane, real runs, 2026-10-07)

- Check 1 (lane open): `git status --porcelain | grep billing` → **9 files**
  (`lib/xaas/billing.ex`, `lib/xaas/billing/subscription.ex`,
  `approval_invoice_reconciliation_approve.ex`, `approval_patch_sla_credit_apply.ex`,
  `approval_pricing_override.ex`, `approval_quota_override.ex`,
  `approval_sla_credit_apply.ex`, `approval_tier_downgrade.ex`,
  `test/xaas/billing/approval_lifecycle_deepening_court_test.exs`).
- Waited 10 min (staged-plan protocol), rechecked once after a further 4 min:
  **identical 9-file set, unchanged**. Same GraphQL-removal in-flight class
  W984az attributed (W984aq lane). No W984u-or-successor billing-integration
  receipt exists on disk. Unblock condition not met → no implementation, court,
  mutation kill, or register flip this lane.

## Added capital this lane: per-site atomicizability classification

W984az staged the plan; this lane read all 8 change modules and all 8 resource
action bodies and classified each site, so the next lane's Step 1 is mechanical.
All paths under `/Users/sac/xaas/lib/xaas/billing/`.

| # | action | change module | classification | real-body evidence |
|---|---|---|---|---|
| 1 | `Subscription :sync_from_stripe` | `changes/subscription_charge_on_activate.ex` | NON-ATOMICIZABLE (disclose) | `after_action` reads `changeset.data.status` (pre-change struct), conditional `newly_activated?/2`, and `open_or_get_account/1` read-or-create on Ledger `Account`. |
| 2 | `Subscription :change_tier` | `changes/subscription_prorate_tier_change.ex` | NON-ATOMICIZABLE (per-site disclosure: non-atomic change module; `after_action` is already in-transaction) | `change/4` captures `changeset.data.tier` + `get_argument(:tier)`, Decimal proration math, conditional transfer direction, read-or-create account. |
| 3 | `ApprovalPricingOverride :approve` | `changes/approval_pricing_override_approve.ex` | **ATOMICIZABLE (convert candidate)** | Change module is a no-op stub (`def change(c,_,_), do: c`); the action's only non-atomic suspects are `change(filter(expr(is_nil(approved_by))))` + a validation. Drop `require_atomic?(false)`, compile, run. |
| 4 | `ApprovalSlaCreditApply :approve` | `changes/approval_sla_credit_apply_approve.ex` | NON-ATOMICIZABLE (disclose) | `newly_approved?/2` reads `changeset.data.approved_by` pre-state; `credit_sla/1` does `open_or_get_account/1` read-or-create then nested `Ash.create(Transfer)`. Money-mover; court block (b) target. |
| 5 | `ApprovalTierDowngrade :approve` | `changes/approval_tier_downgrade_approve.ex` | NON-ATOMICIZABLE (disclose) | `apply_downgrade/1` does `Ash.get(Subscription,...)` + nested `Ash.update(:change_tier)` (itself nesting another after_action Ledger write) inside `after_action` — chained non-atomic changesets. |
| 6 | `ApprovalInvoiceReconciliationApprove :approve` | `changes/approval_invoice_reconciliation_approve_approve.ex` | **ATOMICIZABLE (convert candidate)** | No-op stub change; same shape as #3. |
| 7 | `ApprovalPatchSlaCreditApply :approve` | `changes/approval_patch_sla_credit_apply_approve.ex` | NON-ATOMICIZABLE (disclose) | Same evidence class as #4: `newly_approved?/2` pre-state read + `open_or_get_account/1` read-or-create + nested `Ash.create(Transfer)`. |
| 8 | `ApprovalQuotaOverride :approve` | `changes/approval_quota_override_approve.ex` | **ATOMICIZABLE (convert candidate)** | No-op stub change; same shape as #3/#6. |

## Key insight for the next lane (falsifier warning)

All five non-atomicizable sites use `Ash.Changeset.after_action/2`, which already
runs **inside** the parent transaction — an `{:error, _}` return rolls back the
approval write too. W984az's named falsifier ("court block (b) passes against the
un-converted `after_action` body unchanged → SPEC-08 reduces to disclosure-only")
has a high prior of firing: the after_action bodies already provide the
approved-not-credited isolation the retrofit was meant to add. The next lane
should run the court BEFORE converting anything, on the unconverted tree, and
expect the disclosure-only branch.

## Next-lane execution contract (Steps 0–4 as staged in w984az, minus discovery)

- Precondition: `git status --porcelain | grep billing` → empty, and a
  W984u-successor billing-integration receipt on disk.
- Step 0: baseline `mix compile` + `mix test test/xaas/billing/ --trace` under
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bd`.
- Step 1: convert sites 3/6/8 (drop `require_atomic?(false)`, compile gate);
  add one-line atomicity disclosures to sites 1/2/4/5/7 change-module moduledocs
  — do NOT force conversions.
- Step 2: Chicago court at `test/xaas/billing/atomic_retrofit_court_test.exs`
  (ledger-rollback block (a), `Task.async` double-approve block (b) with
  `Sandbox.start_owner!/2` per task, exactly-one-Transfer assertion). Run the
  court on the UNCONVERTED money-mover (#4) first — this decides the falsifier.
- Step 3: mutation kill (revert-style file swap on #4, court RED, restore, ×2
  green with real tails).
- Step 4: register flip W729 OPEN→REPAIRED only if court kills AND greens;
  else disclosure-only finding recorded here and in the register.

## Standing summary

| item | standing |
|---|---|
| W729 / SPEC-08 implementation | BLOCKED(billing-tree-hot) (fresh ×2 checks, 14 min apart) |
| Per-site classification (8 sites) | ALIVE as staged plan (real reads, no execution) |
| Court + mutation kill | NOT EXECUTED (tree hot) |
| Court first on unconverted tree (falsifier) | staged instruction, next lane |
| Register flip | NOT DONE (gated on court kill+green) |

## Falsifiers carried forward

- Court block (b) passing against the unconverted `after_action` body → SPEC-08
  is disclosure-only; record the finding, don't force.
- Court block (b) failing to fail under mutation → anti-vacuity failure; no flip.
