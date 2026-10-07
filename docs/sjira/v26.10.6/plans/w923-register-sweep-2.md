# W923 — Register Sweep 2 (retry of W915's post-repair status flips)

Wave: v26.10.6, lane W923. Date: 2026-10-07.
Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface` (working tree, uncommitted; no commit per lane contract). No build root created.

## Task

Retry of W915's sweep (`w915-register-sweep.md`, standing IN-FLIGHT-PROGRESS at 0/3
batch receipts). Poll for W897/W900/W902 batch-repair receipts; flip corresponding
rows in `w859-typed-gap-register.md` OPEN → REPAIRED with dual citations; recompute
totals; append final repaired-rows line to W891's progress footer.

## Observed

Poll (`test -f`) across 4 rounds, ~10 min total wait budget:

- Round 1 (t=0): 0/3 (`w897-cheap-repairs.md`, `w900-batch2-repairs.md`, `w902-batch3-repairs.md` all missing).
- Round 2 (t≈+3 min): **`w900-batch2-repairs.md` LANDED**; other 2 missing.
- Round 3 (t≈+6.5 min): still 1/3.
- Round 4 (t≈+9.5 min, budget exhausted): still 1/3.

## Flips performed (from w900-batch2-repairs.md's repaired-row list)

1. **W765 GAP-A** (register row: `expires_at` not accepted by `:issue`):
   OPEN → **REPAIRED**. Citations: `w765-export-token-deepening.md` (original
   disclosure) + `w900-batch2-repairs.md` (accept-list repair, real-action-surface
   court 17 passed exit 0, mutation-reverted run 15/17 confirms load-bearing).
2. **W770 vacuous approvals**: OPEN → **REPAIRED**. Citations:
   `w770-platform-deepening.md` (original disclosure) + `w900-batch2-repairs.md`
   (REPAIRED by W792's landed approver wiring, witnessed by this lane;
   `platform_route_deepening_test.exs` 19 passed exit 0).
3. **W674-GAP-2**: NOT flipped. w900's receipt records the typed-refusal fix as
   staged on tree by W674's lane, but its suite runs 7/11 from unfiltered
   `Ash.read!(ActuationReceipt) |> hd()` shared-DB pollution — not a witnessed
   repair. Row left **OPEN** with a disclosure annotation citing w900's receipt.

## Totals recomputed

Note: since W915's sweep, a W938 row (dead-branch `maybe_refusal/2`) was added to
the register; on-disk totals before this sweep were 43 rows (36 OPEN + 5 REPAIRED +
2 TYPED-OPEN), not the 42 recorded by W915.

- After flips: **43 rows — 34 OPEN + 7 REPAIRED + 2 TYPED-OPEN.**
- REPAIRED list now: W763-G1→W780; W796-G2→W809; W650c GAP-1/2→W676; W650c GAP-4→W659d;
  W650c GAP-3→W865; W765 GAP-A→W900-batch2; W770→W900-batch2/W792.

## Footer update

`w891-gap-triage.md` execution-progress footer (from W914) extended with a
"Final footer update (W923 register sweep 2)" subsection: 2 rows repaired/witnessed,
8 rows in flight (W897 items 1-3, W902 items 7-10), remaining 32 OPEN untouched.

## Standing: PARTIAL_ALIVE

- Register flips: done for the one landed batch receipt (w900), dual-cited, totals
  consistent (verified by re-deriving 34+7+2=43 against the on-disk row list).
- Full sweep closure: blocked on `w897-cheap-repairs.md` and `w902-batch3-repairs.md`
  landing; re-dispatch this sweep a third time after they do (their rows: W804,
  W729, W665, W793, W750, W849, W796, plus W674-GAP-2 disposition).

## Replay

```bash
ls /Users/sac/xaas/docs/sjira/v26.10.6/plans/w897-cheap-repairs.md \
   /Users/sac/xaas/docs/sjira/v26.10.6/plans/w900-batch2-repairs.md \
   /Users/sac/xaas/docs/sjira/v26.10.6/plans/w902-batch3-repairs.md
sed -n '21p;34p;38p' /Users/sac/xaas/docs/sjira/v26.10.6/plans/w859-typed-gap-register.md
sed -n '/Totals by status/,$p' /Users/sac/xaas/docs/sjira/v26.10.6/plans/w859-typed-gap-register.md
tail -15 /Users/sac/xaas/docs/sjira/v26.10.6/plans/w891-gap-triage.md
```

## Honesty boundaries

- Edits: register rows 21/34/38 (2 status flips + 1 annotation), register totals
  block, w891 footer. No code, no tests run, no commit.
- Zero-flip claim would have been false this round: w900 was on disk before the
  first edit; all citations quote its real receipt text.
