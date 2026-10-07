# W984ch — Held-back register + DONE-lane receipt commit (receipt)

**Lane**: W984ch · **Branch**: `feat/playwright-surface` · **Commit**: `22331eb8935107c43ab96cbca49933428aeef0df` (12 files, 961 insertions, 9 deletions)

## Gate

`docs/sjira/v26.10.6/plans/w984ao-graphql-removal.md` present on disk
(verified by `ls`), per W984cd manifest. Held-back register cleared to land.

## Register tally verdict — MATCH

Fresh awk over the status column (field 5) of the 51 data rows of
`w859-typed-gap-register.md`:

| Status | Count |
|---|---|
| REPAIRED | 40 |
| OPEN | 7 |
| TYPED-OPEN | 2 |
| OUT-OF-SCOPE(removed-by-operator, 2026-10-07) | 2 |

Matches the expected ~40/7/2/2 and the register's own on-disk claim (line
111). 51 total rows.

## Staged DONE-lane receipts (11)

`w984as`, `w984ay`, `w984az` (terminal BLOCKED standing = completed typed
refusal, not a running lane), `w984bd` (BLOCKED), `w984bf`, `w984bg`,
`w984bi`, `w984bj`, `w984bm`, `w984br`, `w984cb`.

Every file was content-read before staging: first line + standing checked;
terminal standing confirmed. `w984br`'s "IN-FLIGHT" text refers to *cited*
lanes (w984ao/w984bk receipts), not the receipt itself — and w984ao has
since landed on disk (gate above), so the receipt is terminal.

## Exclusions (conservative — not staged)

- `w984aw` — already tracked (committed earlier), not untracked.
- `w984bn`, `w984bt`, `w984bu`, `w984bw`, `w984bx`, `w984by`, `w984ca`,
  `w984cc` — files absent on disk; lanes not confirmed complete. Skipped.
- All other untracked `plans/*.md` (w969d commit-msg, w984a/aa/ac/ad/ae/
  ak/al/am/ar/at/au/av/ax/bb/bc/be/bh/bk/bz/c, etc.) — not in the
  coordinator's stage list for this lane.

## Method

Explicit pathspec only: `git commit -F w984ch-commit-msg.txt -- <12 paths>`.
No push. No mix commands. Receipt committed as a second explicit-pathspec
commit (this file).
