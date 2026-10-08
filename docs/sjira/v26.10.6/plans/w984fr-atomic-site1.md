# W984fr — W729/SPEC-08 atomic-update plan: ALREADY-LANDED verification receipt (W984cc conversion re-witnessed)

- Lane W984fr, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`
  (dirty campaign tree; **no commit made** — coordinator owns commits).
- Writes this lane: this receipt ONLY. **Zero production/test file edits.**
- `_build-laneW984fr` deletion was **DENIED by the permission system**
  (`rm -rf /Users/sac/xaas/_build-laneW984fr` refused) — the directory is
  left on disk for the coordinator to remove.

## Standing: ALREADY-LANDED (dispatch premise stale)

The dispatch asked this lane to convert the first atomicizable W729/SPEC-08
site. Ground truth on disk: **lane W984cc already executed the full
w984az/w984bd contract** (`w984cc-spec08-execute.md`, commit `8a105e86`):

- All 3 atomicizable sites (3/6/8: `ApprovalPricingOverride`,
  `ApprovalInvoiceReconciliationApprove`, `ApprovalQuotaOverride`)
  converted — `require_atomic?(false)` dropped, `atomic/3` added to the
  three `*RequiresApprover` validations + no-op stub change.
- All 5 non-atomicizable sites (1/2/4/5/7, including the register row the
  dispatch named: `Subscription :sync_from_stripe` /
  `subscription.ex:226` — dispatch line numbers 113/127 are stale;
  `Subscription :change_tier` at :244) carry typed `## Atomicity
  disclosure` sections.
- Court `test/xaas/billing/atomic_retrofit_court_test.exs` exists (real
  Postgres, Task.async double-approve, forced-ledger-failure rollback,
  converted-site leg, mutation kill per `w984cc-spec08-execute.md`).
- Register row W729 UNSUPPORTED(atomic_update) already **FLIPPED →
  REPAIRED** in `w983p-register-flips.md` row 36.

Converting again would have been a duplicate write against the one-writer
law, so this lane re-witnessed the landed state instead.

## Re-witness (this lane, real runs, MIX_BUILD_ROOT=_build-laneW984fr)

| gate | command | real output | exit |
|---|---|---|---|
| compile | `mix compile` | `Generated xaas app` | 0 |
| billing family (incl. subscription + atomic court) | `mix test test/xaas/billing/` | **74 passed, 0 failures** | 0 |
| eu_ai_act census (canonical invocation per w984ec/w984ey) | `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap` | **Result: 1388 passed, 1 excluded** | 0 |
| mock gate | `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'` | `[]` | 0 |

Subscription typed behavior re-witnessed through the live actions inside
the 74-test billing run: tier-change refusals/proration
(`subscription_tier_proration_depth_w984dd_test.exs`,
`subscription_stripe_transition_court_w984dp_test.exs`,
`subscription_test.exs`) and approval gating
(`approval_*` courts incl. `atomic_retrofit_court_test.exs`) — all green
with zero mocks.

## Remaining-site count (re-read from disk this lane)

`grep -n require_atomic lib/xaas/billing/*.ex` → **5 sites remain**, all
classified non-atomicizable with disclosure sections landed (W984cc):

1. `lib/xaas/billing/subscription.ex:226` (`:sync_from_stripe`)
2. `lib/xaas/billing/subscription.ex:244` (`:change_tier`)
3. `lib/xaas/billing/approval_sla_credit_apply.ex:145`
4. `lib/xaas/billing/approval_tier_downgrade.ex:164`
5. `lib/xaas/billing/approval_patch_sla_credit_apply.ex:128`

## Standing summary

| item | standing |
|---|---|
| W729 / SPEC-08 conversion | ALREADY-LANDED (W984cc, commit 8a105e86) — re-witnessed ALIVE by this lane's gates |
| Register flip W729 atomic_update → REPAIRED | already landed (w983p row 36) |
| New production diff from this lane | NONE (one-writer law) |
| `_build-laneW984fr` cleanup | DENIED (permission system); left for coordinator |

## Falsifier note

W984bd's falsifier ("court passes against unconverted `after_action`
body → disclosure-only") already fired under W984cc; nothing in this
lane's re-witness contradicts it — the 74/74 billing run includes both
the unconverted money-mover legs and the converted-site leg.
