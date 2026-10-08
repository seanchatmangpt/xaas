# W650h15 — Landing receipt (fleet seal v26.10.7)

Lane W650h15 · Branch `feat/playwright-surface` · 2026-10-07 · Repo `/Users/sac/xaas`

## Mandate

From W650h14b truth table: stage the 3 green untracked court tests, author the
missing w650y3 receipt, leave RED w984dg excluded, gate = fresh strict compile
EXIT=0 + 3 suites green ×1, push ff.

## Outcome: SUPERSEDED-IN-PART / PARTIAL_ALIVE

Commit 1 (3 test files) was fully executed by the concurrent lane W650h16 at
`bdc6d823` before this lane's commit landed. Evidence: HEAD moved
b522fb45 → 983ca0ae mid-lane; `git ls-tree HEAD` shows
`test/xaas/conference/registration_status_transition_court_w650y4_test.exs`
and `test/xaas/governance/w984dr_environment_court_test.exs` tracked at
bdc6d823; w650y3's file was deleted from the tree by the W984dp3 rotation
(its replacement `w984dp3_atlassian_cursor_court_test.exs` is tracked with
receipt `docs/sjira/v26.10.6/plans/w984dp3-sjira.md`). A concurrent index
collision was observed (this lane's `git add` outputs vanished; other lanes'
files were staged); no tree mutation was made by this lane for commit 1 —
correct outcome, the target content is already in history.

Commit 2 (w650y3 receipt): **AUTHORED AND COMMITTED by this lane** —
`docs/sjira/v26.10.7/plans/w650y3-cursor.md`, standing RETIRED(SUPERSEDED).

## Gates executed (real output)

- Fresh strict compile: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
  MIX_BUILD_ROOT=_build-laneW650h15 mix compile --force` → **EXIT=0**
  (warnings pre-existing in `lib/xaas/operations/refusal_ledger_export.ex`
  only — not session-introduced).
- 3 suites ×1 (w650y3, w650y4, w984dr), HEAD-tree at time of run:
  **10 passed, 0 failures** (1.2s). Green witnessed before supersession.

## w984dg note for owner

`test/xaas/marketplace/catalog_consumption_depth_w984dg_test.exs` remains
RED 4/22 (all in-file; signature: expected `Ash.Error.Query.NotFound`, code
path doesn't raise; first failure at line 116), unreceipted, and stays
excluded per W650h14b. W650h16 confirmed the same exclusion. A transient
staging of this file by another lane was observed in the shared index; it was
not committed by this lane.

## Standing

- w650y4 court: ALIVE (landed bdc6d823, tracked).
- w984dr environment court: ALIVE (landed bdc6d823, tracked).
- w650y3 court: RETIRED(SUPERSEDED) by w984dp3 court.
- Lane W650h15: PARTIAL_ALIVE — receipt authored+committed (commit 2);
  commit 1 superseded by concurrent identical landing (bdc6d823).

## Falsifier

`git log -- docs/sjira/v26.10.7/plans/w650y3-cursor.md` empty after push, or
w650y4/w984dr files absent from HEAD, reopens this lane.
