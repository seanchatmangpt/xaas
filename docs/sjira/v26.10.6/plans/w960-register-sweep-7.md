# W960 — Register Consolidation Flip Sweep 7 (receipt)

- **Lane**: W960, v26.10.6 campaign. Repo `/Users/sac/xaas` @ `feat/playwright-surface`; no commit (coordinator owns commits).
- **Files touched**: `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md` (status flips + totals), this receipt. No build root, no production code.
- **Standing**: ALIVE — all flips receipt-backed by `test -f` + read of w945b / w897 / w925 / w928 receipts; totals re-derived by awk field-5 count on disk.

## Flips (3)

| Row | Before → After | Status receipt |
|---|---|---|
| W674-GAP-1 (gymact non-2xx seal/`:failed` receipt) | OPEN → REPAIRED | w674 (disclosure) + w902-batch3-repairs.md (verify-first: staged `lib/xaas/operations/gymact_surface.ex` seals GAP-1 as `:failed` with json-safe error maps) + w928-gymact-hygiene.md (court 11/11 ×2, exit 0) + w945b row-selection audit re-witness |
| W799 UNSUPPORTED(credit-path-unfundable) | OPEN → REPAIRED | w799 (disclosure) + w945b-batch4-repairs.md row 28 (verify-first, no new code; `allow_overdraft: true` sufficiency exemption in-tree at `approval_sla_credit_apply_approve.ex:119`; falsifier suite 5/5 exit 0 ×2 fresh `_build-laneW945b`) |
| W849 backlog-3 (McpScope moduledoc provenance form) | OPEN → REPAIRED | w849 (disclosure) + w945b-batch4-repairs.md row 35 (code repair, repo-relative regen command; new sha pin `8713a4bc…`; 1/1 ×2; pin-corruption mutation killed, on-disk re-hash matches pin) |

## Citation discrepancy (disclosed)

Dispatch named "W674-GAP-1 → w897-cheap-repairs.md row 1". On disk, w897 row 1 is
**W665** (EU-AI-Act bare technique atom), not W674-GAP-1. Actual GAP-1 backing is
w902 + w928 + w945b. Flip proceeds on those receipts; disclosure note added to the
register row.

## Verified, not double-flipped

- **W674-GAP-2** — already REPAIRED on disk (w900 staging + w928 court, flipped by
  W950/sweep 5). Row re-read; no change.
- **w925-covered rows** — W893 CancelDoesNotReleaseSlot already REPAIRED (sweep 6);
  w925's second disclosure W893 GAP(NoServerActionForCancel) stays OPEN per w925
  itself ("remains open — out of W925 scope").
- **w928-covered row** — GAP-2, covered above.

## Observed, not flipped (out of dispatch scope)

w897-cheap-repairs.md has landed, mutation-killed repairs for three rows still
marked OPEN: **W665 kernel gap** (row 1), **W729 lifecycle-state-machine** (row 5),
**W731 registry-path-hardcoded** (row 11). Left for a dispatch that names them —
noted here so the next sweep lane can pick them up (potential 3 more flips).

## Final totals (awk field-5 on disk, post-edit)

49 rows = **27 OPEN + 20 REPAIRED + 2 TYPED-OPEN**
(verify: `awk -F'|' '/^\|/ && NR>17 && NR<68 {gsub(/ /,"",$5); s[$5]++; n++} END {for (k in s) print k, s[k]; print "rows", n}' w859-typed-gap-register.md`
→ OPEN 27, REPAIRED 20, TYPED-OPEN 2, rows 50 incl. the header separator row).

## W859 register update block appended

Sweep-7 annotation appended to the register's update log with flips, discrepancy
disclosure, and observed-not-flipped list; sweeps 4-6 annotations read and kept
intact (concurrent-edit reconciliation).
