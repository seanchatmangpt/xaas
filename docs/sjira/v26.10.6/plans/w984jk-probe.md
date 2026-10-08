# W984jk — invoice-family unclaimed probe receipt

- Subject: branch `feat/playwright-surface` (checkout `/Users/sac/xaas`), lane W984jk, 2026-10-07. No commit (per dispatch).
- Family: `lib/xaas/billing/approval_invoice_reconciliation_approve.ex` + `validations/approval_invoice_reconciliation_approve_requires_approver.ex` + `changes/approval_invoice_reconciliation_approve_approve.ex` (no standalone `invoice.ex` exists).
- Court: `test/xaas/billing/invoice_resource_court_w984jk_test.exs` — 3 tests, real sandboxed Postgres, real Ash actions, zero mocks.

## Census / dispositions

| Branch | Disposition |
|---|---|
| create happy / create 401 (HTTP) | COVERED — controller test |
| approve happy / missing approver / self-approval / approve 401 (HTTP) | COVERED — controller test |
| RequiresApprover validation wiring, zero-row stale guard (1b), double-approve race (3b), cross-tenant read/approve (4a/4b) | COVERED — approval_lifecycle_deepening_court_test.exs |
| change module `ApprovalInvoiceReconciliationApproveApprove` | COVERED (identity) — gov_long_tail_court_w984ea_test.exs; note: it is a registered no-op passthrough (dead change) |
| **create accepts `:approved_by` with no maker-checker validation** | **UNCOVERED — courted (tests 1+2): a requester can mint an already-approved row (approved_by == requested_by), bypassing maker-checker entirely; the W984k is_nil guard then makes it irreversible — no checker can retroactively sanction. Typed finding `CREATE_APPROVED_BY_BYPASS`** |
| create without `requested_by` (allow_nil? false) | UNCOVERED at action layer — courted (test 3) |
| money-typed / line-item math | N/A — this resource carries no money attributes (cents-bearing SLA-credit resource is the W650v5/W746 sibling) |

## Gates (real output)

- `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984jk mix test test/xaas/billing/invoice_resource_court_w984jk_test.exs` → `Result: 3 passed` (exit 0)
- Sibling SLA courts: `approval_lifecycle_deepening_court_test.exs` + `approval_invoice_reconciliation_approve_controller_test.exs` + `gov_long_tail_court_w984ea_test.exs` → `Result: 18 passed` (exit 0)
- Mock gate `scan_mock_usage(["test","lib"])` → `[]`
- Build root `_build-laneW984jk` deleted post-run.

Standing: PARTIAL_ALIVE (family courted; `CREATE_APPROVED_BY_BYPASS` residue opened, not repaired — repair belongs to the resource owner, one-line fix: drop `:approved_by` from the `:create` accept list).
