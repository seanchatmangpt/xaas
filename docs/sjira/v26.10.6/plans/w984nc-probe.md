# W984nc — docs deepening (cite landed lib repairs) receipt

Lane W984nc, 2026-10-08, branch `feat/playwright-surface` at the shared
canonical checkout `/Users/sac/xaas`. Docs-only lane: no commit, no build
root, no lib changes.

## Verified inputs (all read on disk before citing)

- `docs/sjira/v26.10.6/plans/w984kk-repair.md` — EXISTS.
- `docs/sjira/v26.10.6/plans/w984jz-repair.md` — EXISTS.
- `docs/sjira/v26.10.6/plans/w984ks-retirement.md` — EXISTS.
- `d3189b40` (W984kk/W984jz/W984kg landing) and `4371fcff` (W984ks
  retirement) both on branch, verified via `git show --stat`.
- Code verification: `mcp_typed/2` `case`-in-do-branch answering
  `:notification -> send_resp(conn, 204, "")` at
  `lib/xaas_web/controllers/execution_fabric_controller.ex:353-356`;
  `accept([:requested_by, :org_id])` (no `:approved_by`) at
  `lib/xaas/billing/approval_invoice_reconciliation_approve.ex` ~:102,
  `:approve` keeps `accept([:approved_by])`; the 2 billing change modules
  absent from `lib/xaas/billing/changes/` (only 6 legit files remain).

## Diff (2 files)

1. `docs/claude/diataxis/reference/actuation-and-semantics.md` — dated
   "Verified 2026-10-08 (lane W984nc)" blockquote appended to the
   Re-approve guards section: cites W984jz create accept-list repair
   (`:approved_by` removed from `:create` on
   `Xaas.Billing.ApprovalInvoiceReconciliationApprove`, receipt
   `w984jz-repair.md`, landed `d3189b40`). The doc has NO MCP surface
   discussion, so W984kk's notification fix is not cited here (per task
   condition "if the doc discusses those surfaces" — it does not).
2. `docs/claude/diataxis/reference/http-api-surface.md` — new
   "Verified 2026-10-08 (lane W984nc, lib repair citations)" section
   before See Also: (a) W984kk 204 notification-silence shape at
   `/internal-api/execution/mcp`, with the with-else-vs-case rationale
   and controller line refs; (b) the w984ho `rpc/validate` asymmetry
   entry re-checked — NO repair landed for it (no repair receipt on
   disk; `Atomizer.atomize_requested_fields/3` crash is upstream
   ash_typescript 0.18.2), so it stands as disclosed defect, explicitly
   marked UNKNOWN/not-repaired rather than cited as repaired.

## Typed dispositions

- `SKIP(W984ks/architecture-overview)` — item 3 not patched: grep of
  `docs/claude/diataxis/explanation/architecture-overview.md` for
  `ApprovalInvoiceReconciliationApproveApprove`,
  `ApprovalQuotaOverrideApprove`, `orphan`, `dead`, `retire`,
  `conservation` finds no naming of the retired modules in the
  conservation narrative (only an unrelated W984kg verified block at
  :143). No surface to cite into; a patch would have been unreceipted
  invention.
- `SKIP(w984ho-repair)` — no `w984ho-repair.md` on disk (only
  `w984ho-probe.md`); the rpc/validate defect is not repaired, doc entry
  left as disclosed and annotated.

## Gates

Docs-only diff (2 .md files + this receipt). No compile/test gates apply;
mock gate not applicable (no `lib/`/`test/` changes). Files re-read
post-edit via Edit-tool success + grep of the dated section headers.
