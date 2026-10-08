# W984km — wave-level consolidated manufacturing receipt (lane receipt)

- Lane: W984km, 2026-10-08. Docs-only lane: no commit, no build root.
- Deliverable: `docs/sjira/v26.10.7/plans/w984km-wave-receipt.md`
  (consolidated law-7 receipt for the v26.10.7 deepening wave,
  W984da → W984km).
- Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `b6fad269`
  at write time; origin == HEAD == `f446d9c5` per W984kb push
  reconciliation.

## Commands / exits (real outputs)

- `ls docs/sjira/v26.10.6/plans/w984*.md docs/sjira/v26.10.7/plans/*-commit.md`
  → 178 lane receipts in range enumerated (W984da–W984km) plus the
  v26.10.7 landing/push receipts.
- Mechanical extraction of each receipt's maximal recorded green run
  (< 500; census-scale reruns 1355/1388 excluded as shared-suite runs):
  `grep -oE '[0-9]+ passed' <receipt> | grep -oE '[0-9]+' | awk '$1<500' | sort -n | tail -1`
  per file → 144 receipts with recorded runs, sum **2334 test-passes
  cited**; 34 receipts without a sub-census run (docs-only/recensus/
  registry/disposition lanes), all enumerated in the wave receipt §5.
- Verification: the wave receipt's §5 table was re-parsed from disk and its
  figures compared against the extraction (`/tmp/l_all.txt`): 144 rows,
  table sum == 2334 (exact match).
- Landed-subject cross-check: W984iz manifest (63-commit range
  `5e03acf5..3961c4ab`), W984jm batch #10 (4 commits, batch gate 160
  passed / 0 failures), W984kb push reconciliation (origin == HEAD ==
  `f446d9c5`; `git merge-base --is-ancestor 145b5659 HEAD` exit 0).

## μ / diff

- 1 new file: `docs/sjira/v26.10.7/plans/w984km-wave-receipt.md`
  (consolidated wave receipt: wave shape, landed subjects/batches + SHAs,
  13 lib/ repairs with receipt + landing subject each, open typed findings
  incl. W984ho→W984kk IN-FLIGHT and W984jk→W984jz IN-FLIGHT, complete
  144-row citation table, standing).
- 1 new file: this receipt. Generated vs handwritten: handwritten
  (docs-only; no generator surface for sjira receipts).

## Standing

- Wave receipt: **ALIVE** as a docs surface — every count is arithmetic
  over cited numbers read from the cited receipts; SHAs are cited from
  batch receipts, not inferred.
- Commit execution: UNKNOWN — coordinator-owned; no git write, no build
  root created by this lane.
- Falsifier: any figure or SHA in the wave receipt not reproducible from
  the cited receipt or `git log` at `b6fad269` falsifies it.
