# W984jz — CREATE_APPROVED_BY_BYPASS repair receipt

- Subject: branch `feat/playwright-surface` (checkout `/Users/sac/xaas`), lane W984jz, 2026-10-08. No commit (per dispatch).
- Repairs finding `CREATE_APPROVED_BY_BYPASS` typed by W984jk
  (`docs/sjira/v26.10.6/plans/w984jk-probe.md`): `Xaas.Billing.ApprovalInvoiceReconciliationApprove`'s
  `:create` accepted `:approved_by`, letting a requester mint an
  already-approved row that the W984k `is_nil(approved_by)` approve guard
  can never re-enter (irreversible self-approval).

## Diff (2 files)

1. `lib/xaas/billing/approval_invoice_reconciliation_approve.ex` — one-line
   accept-list repair: `accept([:requested_by, :approved_by, :org_id])` →
   `accept([:requested_by, :org_id])`, with a comment block citing the
   W984jk receipt. Rows now always start unapproved; approval can only be
   minted through `:approve`, where the RequiresApprover maker-checker
   validation and the W984k stale guard apply.
2. `test/xaas/billing/invoice_resource_court_w984jk_test.exs` — bypass pins
   converted to repair pins:
   - Test 1 now asserts the create-with-`:approved_by` attempt is refused
     typed (`Ash.Error.Invalid.NoSuchInput{input: :approved_by}`; asserted
     against the real struct via mix run probe) AND that a clean create
     starts unapproved (`approved_by == nil`).
   - Test 2 now proves the W984k guard is reachable for every row: fresh
     row → real `:approve` by a distinct checker succeeds
     (maker-checker path intact).
   - Test 3 unchanged (allow_nil? pin), still green.

## Consumer census (no other consumer depends on creating pre-approved rows)

`grep -rn "ApprovalInvoiceReconciliationApprove" lib/ test/` → consumers:
billing.ex domain, system_actor.ex, subscription.ex (doc-reference only),
validation/change modules, controller test, multitenancy court,
system_authority_service_scope test, lifecycle deepening court, gov long
tail court. `grep` for create-with-approved_by in every consumer → zero
matches; only W984jk's own bypass-pin tests supplied `:approved_by` at
create time.

## Gates (real output)

- Court: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984jz mix test test/xaas/billing/invoice_resource_court_w984jk_test.exs` → `Result: 3 passed`
- Siblings: same command + `approval_lifecycle_deepening_court_test.exs`, `approval_invoice_reconciliation_approve_controller_test.exs`, `gov_long_tail_court_w984ea_test.exs` → `Result: 21 passed` (3+18, exit 0)
- Resource-touching remainder: `billing_multitenancy_court_test.exs` + `system_authority_service_scope_test.exs` → `Result: 10 passed` (exit 0)
- Mock gate `scan_mock_usage(["test","lib"])` → `[]`

## Standing

- `CREATE_APPROVED_BY_BYPASS` → REPAIRED (typed refusal at changeset layer;
  maker-checker + stale guard now total over all rows).
- Lane build root `_build-laneW984jz` deleted post-run.
