# W967 — Triage final reconciliation

Lane W967, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`. Doc-only
lane: no code, no build root, no commit.

## Subject

Final reconciliation footer for `docs/sjira/v26.10.6/plans/w891-gap-triage.md`
(written; see "Final reconciliation footer (W967, 2026-10-07)" section).

## Sources read (files on disk)

- `w859-typed-gap-register.md` — table + totals re-derived by awk field-5 count at
  read time: **50 rows = 25 OPEN + 23 REPAIRED + 2 TYPED-OPEN** (this post-dates
  sweep 7's 49-row note; W945c's batch-5 flips landed after sweep 7).
- `w897-cheap-repairs.md` (rows 1/5/11 = W665/W729-lifecycle/W731-path, all
  mutation-killed; drift note: triage rows 6/13 already repaired on HEAD by
  W746/W768), `w900-batch2-repairs.md` (rows 15/19), `w902-batch3-repairs.md`
  (rows 23/25/33 witness + 2 new rows), `w925-slot-release.md`,
  `w928-gymact-hygiene.md`, `w947-blocker-status.md` (compile blocker CLEARED,
  exit 0, receipt-only lane), `w947-cancel-action.md` (`update :cancel` landed,
  mutation-killed court 0/1 on removal; register row NoServerActionForCancel not
  yet flipped — no sweep 8), `w907-bare-fun-fix.md`, `w860-health-timeout.md`
  (both witnessed via w944's appended rows), `w964-enoent-ownership-mint.md`
  (manifest ownership chain, no register row).

## Register totals

50 rows = 25 OPEN + 23 REPAIRED + 2 TYPED-OPEN (grep/awk-verified from the table,
not copied from the footer).

## Original-35 disposition

- **Closed: 13** — triage rows 2, 3, 12, 13, 15, 16, 17, 19, 23, 25, 28, 33, 35;
  every one dual/triple-cited to a closing receipt with a mutation-killed court.
- **Partial: 1** — row 4 (W722): gap-1 state guard closed (W740, w945c witness);
  gap-2 split out as its own OPEN row.
- **Remaining: 22** — 16 DESIGN (w905 spec'd; GAP-B/C closed by w935), 5
  CHEAP-REPAIR (rows 1/5/6/11 have landed mutation-killed repairs in w897 but
  register rows stay OPEN pending a naming dispatch; row 29 W804 is a one-command
  operator action, genuinely unexecuted), 1 W784 TYPED-OPEN-promote candidate
  (promotion not executed; register TYPED-OPEN count still 2: W811 + 49.3).

## Standing

PARTIAL_ALIVE — the footer and this receipt are documents on the exact subject;
no tests or builds were run, no gap statuses were flipped (W967's mandate was
doc-only reconciliation, not a register sweep; the 4 w897-repaired rows stay OPEN
in the register per sweep-7 policy until a dispatch names them).

## Falsifier

- Any count above disagrees with an awk field-5 recount of
  `w859-typed-gap-register.md` → footer is stale.
- A register sweep that names w897 rows 1/5/11 (+ row 6's W746 repair) flips 4
  OPEN → REPAIRED, moving totals to 21 OPEN + 27 REPAIRED.
