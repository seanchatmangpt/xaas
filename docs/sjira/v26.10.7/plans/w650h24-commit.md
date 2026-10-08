# W650h24 — Commit Receipt (lane, v26.10.7 fleet seal)

Date: 2026-10-07 · Branch: `feat/playwright-surface` · Base at start: `8a5f7ea7` (fleet-seal head; sibling `dc465f51` landed mid-lane)

## Task (from W650h23 findings)

Delete the stray superseded W650y3 cursor artifacts and land the staged
deletion of the retired plan, citing the supersession chain.

## Supersession chain (verified on disk before rm/commit)

- **Survivor court**: `test/xaas/sjira/w984dp3_atlassian_cursor_court_test.exs`
  — tracked, 5 tests, receipted `5 passed, 0 failures (run 1)` per
  `docs/sjira/v26.10.6/plans/w984dp3-sjira.md` (on disk, read this lane).
- **Retirement**: `docs/sjira/v26.10.7/plans/w650h15-landing.md` line 26 —
  w650y3 standing `RETIRED(SUPERSEDED)`; line 18 — "w650y3's file was
  deleted from the tree by the W984dp3 rotation".

## Actions and results

1. `rm test/xaas/sjira/w650y3_atlassian_cursor_depth_court_test.exs`
   (stray untracked duplicate, superseded by W984dp3's tracked court) —
   removed; untracked-file status for that path now empty.
2. `rm docs/sjira/v26.10.7/plans/w650y3-cursor.md` (stray untracked copy
   at the tracked path) — removed; staged `D` confirmed unchanged.
3. `git commit -F /tmp/w650h24-msg.txt -- docs/sjira/v26.10.7/plans/w650y3-cursor.md`
   — **`78127188`** (`7812718842af750207ae29a96a4c75e88eefcd60`).
   Pathspec-scoped: exactly 1 file changed, 49 deletions, `delete mode
   100644 docs/sjira/v26.10.7/plans/w650y3-cursor.md`. No other staged
   lane work swept in.
4. `git fetch origin` then `git push origin feat/playwright-surface` —
   fast-forward `dc465f51..78127188`, branch in sync with origin after.

## Concurrent-lane note

W650h15b landed `dc465f51` (already pushed) covering the .exs duplicate
drop while this lane ran; this lane's commit is disjoint (`.md` deletion
only). Out-of-scope observation: an untracked
`docs/sjira/v26.10.6/plans/w650y3-cursor.md` exists in the tree — not
touched (not in this lane's mandate).

## Standing

- w650y3 cursor plan: **RETIRED(SUPERSEDED)** — deletion now landed and
  pushed, replayable via `git show 78127188`.
- W984dp3 court: **ALIVE** (tracked, receipted, green on record).
- Lane W650h24: **ALIVE** — all three task items executed with receipts.
