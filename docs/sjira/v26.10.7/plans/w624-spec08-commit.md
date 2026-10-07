# W624 / SPEC-08 integration commit receipt — W984cc landing

- Date: 2026-10-07
- Lane: W624, v26.10.7 campaign (coordinator-delegated SPEC-08 integration; commit only, no push)
- Subject: `feat/playwright-surface` @ commit **8a105e86777d737fd15b8bd18d23ea28e1b95bdf**
  (`fix(billing): W984cc SPEC-08 conversion — approval validations as atomic retrofits (W624/SPEC-08)`)

## Staged paths (explicit pathspec, 16 files, +453/−7)

Lib — billing root (4):
- lib/xaas/billing/approval_invoice_reconciliation_approve.ex
- lib/xaas/billing/approval_pricing_override.ex
- lib/xaas/billing/approval_quota_override.ex
- lib/xaas/billing/approval_sla_credit_apply.ex

Lib — billing/changes (6):
- lib/xaas/billing/changes/approval_patch_sla_credit_apply_approve.ex
- lib/xaas/billing/changes/approval_pricing_override_approve.ex
- lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex
- lib/xaas/billing/changes/approval_tier_downgrade_approve.ex
- lib/xaas/billing/changes/subscription_charge_on_activate.ex
- lib/xaas/billing/changes/subscription_prorate_tier_change.ex

Lib — billing/validations (3):
- lib/xaas/billing/validations/approval_invoice_reconciliation_approve_requires_approver.ex
- lib/xaas/billing/validations/approval_pricing_override_requires_approver.ex
- lib/xaas/billing/validations/approval_quota_override_requires_approver.ex

Tests/docs (3):
- test/xaas/billing/atomic_retrofit_court_test.exs (new)
- docs/sjira/v26.10.6/plans/w983p-register-flips.md
- docs/sjira/v26.10.6/plans/w984cc-spec08-execute.md

## Gate (all under asdf toolchain, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW624)

1. Fresh strict compile: `mix compile --force` → **EXIT=0** (fresh lane root)
2. `mix test test/xaas/billing` → **43 passed**, EXIT=0
3. `mix test test/xaas/billing/atomic_retrofit_court_test.exs` → **3 passed**, EXIT=0
4. Post-commit at HEAD: `mix test test/xaas/billing` → **43 passed**, EXIT=0

## Standing

- Standing: **ALIVE** (exact subject 8a105e86, observed execution, all four gates green)
- Single atomic commit (one coherent conversion + its courts + receipts; disclosed as one
  rather than split lib/tests).
- Commit made with explicit pathspec; `git status` confirms zero remaining uncommitted
  billing/atomic-retrofit files. Not pushed.
- `_build-laneW624` left in place for coordinator per lane lease policy.
