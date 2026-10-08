# W984lb — docs deepening probe: court-witnessed findings into diataxis reference/explanation

- Lane: W984lb, checkout `/Users/sac/xaas` @ branch `feat/playwright-surface`, 2026-10-08.
  Docs-only; no commit, no build root (per lane contract).
- Convention: dated appended verification blockquotes per W984gz.

## Edits (2 files, append-only blockquotes)

1. `docs/claude/diataxis/reference/actuation-and-semantics.md` — dated
   (Verified 2026-10-08) blockquote appended directly under the Reactor
   execution paragraph in **Consequential actuation API**, citing W984ip:
   the `undo: &Xaas.Actuation.Kernel.undo_actuate/3` callback
   (`lib/xaas/actuation.ex:309`, clauses `:448-450`) witnessed at reactor
   level via the boolean-seal trigger (Token `:is_revoked` returns a bare
   boolean; `Kernel.seal/2` fails `InvalidAttribute{field: :result}` because
   the receipt `:result` is typed `:map`), firing real OCEL cancellation
   (`forward_cancellation/1`, Bandit loopback) and full transaction rollback
   (intent/receipt rows absent; key lawfully reusable). Court
   `test/xaas/actuation/reactor_undo_court_w984ip_test.exs` (2 passed, zero
   mocks); stated falsifier included.
2. `docs/claude/diataxis/explanation/architecture-overview.md` — dated
   blockquote appended under the **Reactor Actuation** bullet (the Ultracode
   lease kernel sentence), citing W984kg:
   `Xaas.Ultracode.Lease.record_provider_event/2`
   (`lib/xaas/ultracode/lease.ex:956-962`) now returns the typed
   `{:error, {:no_lease, token}}` for unknown tokens instead of crashing
   BadMapError; the court `test/xaas/ultracode/lease_court_w984kg_test.exs`
   (4/4) plus 81/81 family regression, mock gate `[]`.

## Skipped (receipts absent on disk at lane time)

- W984kk (notification-silence repair) — `docs/sjira/v26.10.6/plans/`
  contains no `w984kk-*` file; http-api-surface.md NOT touched.
- W984ks (dead approval-changes retirement) — no `w984ks-*` file.
- W984jz — receipt EXISTS (`w984jz-repair.md`) but skipped per dispatch
  condition: `docs/claude/diataxis/explanation/ash-is-the-xaas.md` only
  mentions Billing in a domain table row ("maker-checker financial
  approvals", line 178) and does not discuss the
  `ApprovalInvoiceReconciliationApprove` / `:approved_by` accept-list
  surface; verified via grep before skipping.

## Code verification (real output)

- `grep -n undo_actuate lib/xaas/actuation.ex` → `309: undo(&Xaas.Actuation.Kernel.undo_actuate/3)`,
  `448:`/`450:` clauses. Matches receipt claim.
- `sed -n '955,970p' lib/xaas/ultracode/lease.ex` → the `{:ok, nil} ->
  {:error, {:no_lease, lease_token}}` arm with the W984kg comment is on disk.
- Receipt files censused via `ls docs/sjira/v26.10.6/plans/ | grep w984...`:
  present: w984gz-probe, w984ip-probe, w984jz-repair, w984kg-probe;
  absent: w984kk-*, w984ks-*.

## Standing

ALIVE for the docs-only pass: 2 dated blockquotes landed citing only
on-disk receipts and line-verified code; 3 candidate citations skipped with
typed reasons (2 absent receipts, 1 out-of-scope doc). No commit, no build
root, no sibling edits reverted.
