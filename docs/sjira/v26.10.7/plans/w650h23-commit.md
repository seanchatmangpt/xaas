# W650h23 — Commit Receipt (lane, v26.10.7 fleet seal)

- **Subject**: /Users/sac/xaas @ feat/playwright-surface, HEAD `36cadd9d` at lane start
- **Task**: verify/land w650y4 status-transition court; check for stray w650y3 cursor court copy

## Verdict 1 — w650y4 status-transition court: NO-OP (already landed)

- `test/xaas/conference/registration_status_transition_court_w650y4_test.exs` is **tracked at HEAD**.
- Landing commit: `bdc6d823` — "test(courts): W650h16 landing batch — W984dr governance
  courts + W650y4 status-transition court (15/15 green incl. w650y3 pre-deletion, strict
  compile EXIT=0, fresh _build-laneW650h16)".
- `git log -- test/...w650y4_test.exs` returns exactly that commit; no fresh gate run
  re-executed (no untracked subject existed to gate).

## Verdict 2 — w650y3 cursor court: stray untracked copies present, NOT landed

- `test/xaas/sjira/w650y3_atlassian_cursor_depth_court_test.exs` — **untracked** (`??`)
- `docs/sjira/v26.10.7/plans/w650y3-cursor.md` — **untracked** (`??`; the tracked copy
  is already deleted/staged-`D` in the index per W650h15's rotation record)
- These are stray reappearances after W984dp3's rotation. Per lane instruction, they
  were **not staged, not landed**. Supersession holds: coverage carries via W984dp3's
  tracked, receipted, green `test/xaas/sjira/w984dp3_atlassian_cursor_court_test.exs`;
  w650y3's file was never committed (W650h15 receipt, superseded by W650h16 `bdc6d823`).

## Standing

- w650y4 court: **ALIVE** at HEAD via `bdc6d823` (observed in `git log`, not re-run this lane).
- w650y3 artifacts: **UNSUPPORTED(superseded-by-W984dp3)** — left untracked on disk, no commit.

## Commands / exits

- `git log --oneline -- test/xaas/conference/registration_status_transition_court_w650y4_test.exs` → `bdc6d823`
- `git ls-files --error-unmatch <w650y4 file>` → tracked
- `git ls-files` / `git status --short` on w650y3 test + plan files → untracked (`??`)

## Diff

This commit adds only this receipt file. No source/test diff by this lane (NO-OP lane).
Build root `_build-laneW650h23` not created (no gate run needed); nothing to delete.
