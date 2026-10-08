# W984mg — Evidence–Claims Index batch #13 refresh (probe receipt)

- **Lane**: W984mg · 2026-10-08 · checkout `/Users/sac/xaas`, branch
  `feat/playwright-surface` (no branch switch, no stash, no commit).
- **Subject**: extend `docs/cro/artifacts/evidence-claims-index.md` with
  landing batch #13.
- **Head at write time**: `567ab1f5` (rev-parse HEAD ==
  origin/feat/playwright-surface == `567ab1f509cf2fa38e4e8d105748b5b38bb2bde4`;
  zero commits after 567ab1f5 in log).

## What was verified (real outputs)

- Batch #13 = 7 wave commits: `d3189b40`, `be2591bd`, `4371fcff`,
  `9ba3a44f`, `dc125c8c`, `038fd867`, `567ab1f5` (git log at write time;
  nothing newer).
- Each SHA grep-verified against `docs/sjira/v26.10.{6,7}/plans/`:
  6/7 cited by `docs/sjira/v26.10.7/plans/w984lo-commit.md`; `567ab1f5`
  is self-carried (carries that receipt itself; no independent citation
  on disk yet).
- Receipt read in full; gate numbers transcribed from it: compile EXIT=0
  (fresh `_build-laneW984lo`); batch gate 14 court files → 88 passed
  exit 0; title_iii `--include eu_ai_act` → 391 passed (matches w984ke);
  W984ks gate `mix test test/xaas/billing` → 80 passed exit 0 (matches
  w984ks-retirement.md); mock gate `[]`.
- `git show --stat` per commit: d3189b40 3 lib files; be2591bd 12 court
  files; 4371fcff 5 files (2 billing modules deleted, w984er RETIRED
  flips, w984ks-retirement.md); 9ba3a44f 19+ receipt files; dc125c8c 8
  diataxis files; 038fd867 7 files incl. evidence-claims-index (+101/−3,
  the rows 77–95 content); 567ab1f5 receipt carrier.
- Blocker-1 re-observed at this head: `git merge-base --is-ancestor
  56325fa5 origin/main` → exit 1 (unchanged from W984lf's observation at
  `52ce8236`).
- W984lp/W984lq receipts still absent from both plans trees.

## Changes landed (docs-only, uncommitted)

- `docs/cro/artifacts/evidence-claims-index.md`: header stamp adds
  W984mg refresh (rows 96–102) at head `567ab1f5` 2026-10-08 (origin ==
  HEAD); total line now `… → 92 → 102 (W984mg, 2026-10-08)`; rows 96–102
  appended (witnessed 3: #96/97/98; grep 4: #99–102); DRIFT (W984mg)
  added — Blocker-1 unchanged, receipt-absent-by-construction now also
  covers #102 (7 of last 46 wave commits), W984lz's "lo NOT landed" note
  superseded, kn-overlap pathspec dedup disclosure; Counts (W984mg)
  cumulative **102 rows**.

## Standing

ALIVE (docs refresh, grep-graded). Rows transcribed from the on-disk
`w984lo-commit.md` receipt and per-commit `git show --stat`; no test
runs performed by this lane (none owed — refresh lane, gates already
witnessed by W984lo's receipt).
