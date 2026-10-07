# W961b — Fold W944b outcome into campaign record

Date: 2026-10-07. Lane W961b, xaas v26.10.6, branch `feat/playwright-surface`
(HEAD `fab56ae1` at time of edit). Write-only fold: no code, no commit, no
build root.

## Source receipts (real reads)

- `docs/sjira/v26.10.6/plans/w944b-route-collision.md` — route-collision
  court for `AuditExportToken` :use/:revoke: RESOLVED-AT-HEAD, 4 passed,
  distinct routes verified at 3 layers, real HTTP probes 200 with persisted
  asserts; F2 (stale controller tests) out of lane scope.
- `docs/sjira/v26.10.6/plans/w959-controller-repoint.md` — F2 repair landed:
  controller repoint to `/:id/revoke`, 10/10.

## Surface choice

The airo-wiring-ledger's consolidated table is scoped to AIRo ontology
artifacts (per-lane TTL wiring rows); a route-collision court row would be
off-surface there. The witness-live-court-note carries court-evidence lines
for live-court surfaces, so the row was appended there.

## μ/diff (1 line, 1 file)

- `docs/cro/artifacts/witness-live-court-note.md` — appended one court
  evidence bullet: "Court evidence (W944b fold, 2026-10-07): route-collision
  court for AuditExportToken :use/:revoke — 4 passed, RESOLVED-AT-HEAD at
  fab56ae1, distinct routes verified at 3 layers, real HTTP probes 200 with
  persisted asserts; F2 controller repoint landed as W959, 10/10."

## Commands/exits

- `ls -la docs/sjira/v26.10.6/plans/w959-controller-repoint.md` → exit 0
  (file on disk, 2295 B, 2026-10-07).
- Edit applied via Edit tool; on-disk state confirmed by successful
  unique-match replace (no re-read needed).

## Verification ladder

Narrow only — this is a documentation fold; the court itself was executed
by W944b (4 passed) and W959 (10/10) on the exact subject; nothing re-run
here, no claims added beyond the source receipts.

## Standing

ALIVE-as-fold: the campaign record now cites both landed receipts; court
standing remains bound to the W944b/W959 exact subjects (`fab56ae1` +
working-tree test tree), not to this note.
