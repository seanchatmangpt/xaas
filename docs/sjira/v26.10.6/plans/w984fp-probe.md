# W984fp — evidence-claims-index refresh probe (rows 59–76)

Lane W984fp · Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, head
`43265cb1` · 2026-10-07 · Docs-only, no build root, NO commit.

## Task

Refresh `docs/cro/artifacts/evidence-claims-index.md` with the 2026-10-07
evening wave's commits (f0321df2 → 43265cb1, 20 commits): per commit, verify
its receipt exists and cites the SHA (real grep), then add an index row
(claim / subject SHA / court result / receipt path) per the file's existing
row format. Mark stale rows (annotate, don't delete).

## Per-row verification (real commands + output)

SHA→receipt grep over `docs/sjira/v26.10.{6,7}/plans/`, one grep per wave
SHA (`grep -rl <sha> docs/sjira/v26.10.6/plans/ docs/sjira/v26.10.7/plans/`).
Real results:

| SHA | commit | receipt citing/carrying it | grep hits |
|---|---|---|---|
| f0321df2 | W650h22 SpgGate landing | `docs/sjira/v26.10.7/plans/w650h22-commit.md` (subject line: "Commit `f0321df22498503f7afe624f01b0632e79b8fd58`") | w650h22-commit.md + w984ef/eg/ek-probe + runbook |
| ee6c18bc | W650h22 receipt-carrier commit | carries w650h22-commit.md; nothing cites it as subject | w984ef-probe, w650h23-repair, runbook, w650h33-commit |
| 34fc8a53 | W650h33 vkg query_depth | `w650h33-commit.md`: "Commit `34fc8a53` … pushed fast-forward `ee6c18bc..34fc8a53`" | w650h33-commit, w650h33b-commit, runbook, probes |
| 0b1b70fc | W650h33b receipt-only | `w650h33b-commit.md`: "This lane's commit **0b1b70fc** therefore carries the receipt only" | w650h33b-commit, w650h33b/c, runbook |
| d51119c5 | W650h33b git-state correction | covered by w650h33b-commit.md (git-state verdict section) | w984ef-probe, w650h33c-commit, runbook, w650h33b-commit |
| 32b72c4f | W650h33c causal_receipt court | `w650h33c-commit.md`: "commit `32b72c4fcbc06bc466b4cd5ffaad96bc7e60f42e`" | w650h33c-commit + w984ed/ek/eo/eq/ef-probe |
| f2d30813 | W984ds2b wording correction | doc-only; covered by w984ds2b-commit.md scope | w984ef-probe, w650h33b-commit, runbook |
| b75918a5 | W984ds2b receipt-carrier | carries w984ds2b-commit.md | w984ef-probe, runbook |
| 5cf56c13 | W984ds2b courts batch | `w984ds2b-commit.md`: "Commit (exact): `5cf56c13f38f9a5fd901fcaf4854c30eb443a9bd`" | w984ds2b-commit + probes + runbook |
| acacc1db / ab3562b8 / 8f9ea495 | W984el landing batch legs | `w984el-commit.md` commit table lists all three; batch gate 91 passed / 0 failed (14+14+20+33+5+5), mock gate `[]` | w984el-commit + w650h14-gated-commit (base) |
| ecf84663 | W984el receipt-carrier | carries w984el-commit.md; cited as stage-time base by w650h14 | w650h14-gated-commit.md ("Base at stage time: `ecf84663`") |
| 3c03bffa | W650h14 gated batch 1 (16 files) | `w650h14-gated-commit.md`: "commit: **`3c03bffa`**"; gates: compile EXIT=0, census 1354/1355 (1 disclosed concurrent-edit failure, isolated 26/26), batch 57 passed | w650h14-gated-commit + w984fe-commit |
| ed015775 | W650h14 docs commit | same receipt's docs-commit section | w984fh-recensus.md |
| 0153101a / c6bf5bbc / 49992412 / a420b7d5 | W984fe batch #2 legs | `w984fe-commit.md` commit table; batch gate real run 28 passed exit 0 (2+12+3+5+6); mix.lock diff verified exactly 3 deletions | w984fe-commit.md (all four) |
| 43265cb1 | w984et probe + w984fe receipt landing (HEAD at refresh) | **grep zero hits — receipt-absent-by-construction** (`grep -rl 43265cb1 docs/` → no output); commit cannot contain its own hash; content standing inherited from w984fe's batch gates | none |

## Receipts read in full

w984fe-commit, w984el-commit, w650h14-gated-commit, w984ds2b-commit,
w650h33-commit, w650h33b-commit, w650h33c-commit, w650h22-commit (8 files,
381 lines total, `wc -l` output witnessed in-session).

## Edits made (verified on disk post-edit)

- Header lane line now reads "refreshed W711, W855, W984fp"; head stamp
  `43232f…`→`43265cb1` 2026-10-07.
- New section "Claims table — W984fp refresh (rows 59–76)": 18 rows over 20
  commits (batch legs share receipts), same 5-column format.
- Rows 33/34 annotated STALE in place (census 1347/1348 superseded by
  W650h14's 1354/1355, row 70) — annotated, not deleted.
- DRIFT summary + Counts sections appended; trailing "Total rows" line
  updated to `12 → 32 → 58 → 76 (W984fp, 2026-10-07)`.

Post-edit verification:

```
$ grep -c '^| [0-9]' docs/cro/artifacts/evidence-claims-index.md
76
$ grep -n 'STALE' docs/cro/artifacts/evidence-claims-index.md   # rows 33, 64–65 = lines 64, 65
```

76 numbered rows on disk; both STALE annotations present at lines 64–65;
no build root created; nothing committed (working tree carries the index +
this receipt as modified/untracked, per lane contract).
