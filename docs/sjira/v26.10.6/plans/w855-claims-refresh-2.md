# W855 — Evidence–Claims Index refresh 2 (post-W711 landings)

- **Lane**: W855, xaas v26.10.6 campaign, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`, HEAD `a0723bf6`. No commit (coordinator owns
  integration); no build root; only files written:
  `docs/cro/artifacts/evidence-claims-index.md` + this receipt.
- **Standing**: PARTIAL_ALIVE — index refresh complete on the exact subject;
  every row grounded in a receipt read in full this lane; the index itself
  is prose (grep-grade by its own method).

## Result

Claims index extended **32 → 58 rows** (rows 33–58 added), covering the
post-W711 landings. 26 receipt files read in full before writing each row.

## Receipts read (26) and standing observed

- **Census**: w778 (ALIVE, gate 1347/1347 exit 0; F2 coordinator repair was
  direction-inverted, W778 fixed forward), w821 (ALIVE, terminal census
  CERTIFIED — 1347/1348 deterministic ×2, single failure is the 49.3
  `flunk/1` open gap).
- **Repairs**: w809 (PARTIAL_ALIVE, uncommitted — DB-read return guard,
  12/12), w818 (ALIVE — incident guards (a)/(b), 29/29, 3 typed gaps pinned
  open), w831 (PARTIAL_ALIVE, uncommitted — exclusions guard, 25/25 ×2),
  w835 (PARTIAL_ALIVE, uncommitted — SLA-credit overdraft exemption, 5/5,
  closes W799's disclosed RED).
- **Gates**: w760 (BLOCKED at time of writing — 2 deterministic court-side
  failures + 268 warnings; superseded by w778), w770 (PARTIAL_ALIVE — 14
  tests, vacuous-approval gaps disclosed in-file), w799 (PARTIAL_ALIVE — 5
  tests, reversal-action-absent UNSUPPORTED), w802 (UNSUPPORTED(graphql-
  http-surface) — grep-based typed finding), w812 (RESOURCE_ALIVE — 20/20),
  w813 (ALIVE — 11 tests), w817 (ALIVE — 16/16 ×2), w826 (ALIVE —
  findings-only workflow verification), w832 (ALIVE — 6/6 doctests ×2,
  surface = 2 modules), w837 (ALIVE — real-regen byte-compare court, outputs
  identical), w842 (ALIVE priority set — 24 pass / 1 designed skip / 0 fail;
  W842-F1 config-class probe bug recorded, unfixed).
- **Docs**: w815 (ALIVE doc-only — 1 open gap 49.3 registered, totals
  1347/1348), w819 (ALIVE doc-only — GraphQL overclaim fixed from w802
  evidence), w827 (PARTIAL_ALIVE — lease verbs corrected 8→10), w830
  (PARTIAL_ALIVE self-declared), w839 (ALIVE — sweep, 1 accurate historical
  comment, 0 fixes), w841 (grep-grade verify — counts corrected 7/12+ →
  17/19), w849 (census — 12 surfaces: 8 DRIFT-CHECKED / 4 PROVENANCE-ONLY /
  0 UNPINNED), w850 (PARTIAL_ALIVE doc-only).
- **Fleet**: w756 (ALIVE pack-level, **uncommitted in ggen-marketplace** —
  fresh counts 117/152/19, `ggen sync` regeneration coordinator-owned).

## Receipt-absent lanes — skipped, not invented

- **W840-check**: no `w840-*.md` exists in `docs/sjira/v26.10.6/plans/` →
  no row.
- **W854-check**: no `w854-*.md` exists → no row.

## DRIFT recorded

1. **Row 58 (w756) vs row 32 (w689)**: W689 reconciled docs to 116
   resources; W756's fresh grep gives 117 `Xaas.Resource` wrappers (152
   total `use Ash.Resource`). Unreconciled off-by-one — needs one canonical
   recount before the number ships again.
2. **Row 39 (w760)**: its "0 open gaps is real" reading and 1200-test total
   are both superseded (W779/W815: exactly 1 typed open gap; totals
   1347/1348). Recorded as superseded, not silent.
3. Uncommitted-landing set grew to W809/W831/W835 (xaas) + W756
   (ggen-marketplace); coordinator integration pending for all.

## Commands / exits

```bash
ls docs/sjira/v26.10.6/plans/ | grep -E 'w7|w8'   # 26 target receipts confirmed; w840/w854 absent
# 26 receipts read in full (cat/Read); index edited in place
```

No build, no test run, no commit — doc-only lane per dispatch contract.

## Falsifier

Any row whose cited receipt, when re-read at integration, does not support
the row's "what the receipt actually witnesses" cell refutes this refresh;
also, `grep -c "^| 5[89]" evidence-claims-index.md` non-zero (rows beyond
58 invented) refutes the totals.
