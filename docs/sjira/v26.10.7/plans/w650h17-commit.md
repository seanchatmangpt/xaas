# W650h17 — Completed-lane landing batch 2 (commit receipt)

Lane: W650h17, xaas v26.10.7 fleet seal, branch `feat/playwright-surface`, canonical
checkout `/Users/sac/xaas`. Operator-delegated commit+push, explicit pathspec only.

## Subject / commit

- Commit `e483e854` — "test(depth): W650h17 landing batch 2 — W984dq3 + W650y4 courts
  onto HEAD" — pushed ff to `origin/feat/playwright-surface` (`f25ab0ac..e483e854`).

## Per-file table

| file | status at check | owner receipt | action |
|---|---|---|---|
| `test/xaas/bridges/w984dq3_durable_adapter_test.exs` | untracked | `docs/sjira/v26.10.6/plans/w984dq3-durable-adapter.md` (on disk, 5,063 B) | LANDED in `e483e854` |
| `test/xaas/conference/registration_status_transition_court_w650y4_test.exs` | initially `??`, landed mid-lane by W650h16 (`bdc6d823`) | `docs/sjira/v26.10.6/plans/w650y4-status-transition.md` (on disk) | SKIP — already tracked at commit time (W650h16 won the race) |
| `test/xaas/sjira/w650y3_atlassian_cursor_depth_court_test.exs` | not on disk at check time; `w650y3-cursor.md` receipt absent (later found deleted-staged, then re-created untracked by another lane) | `docs/sjira/v26.10.7/plans/w650y3-cursor.md` missing at verify time | SKIP — W650h15 receipt (`1555f02e`) states commit 1 superseded by W650h16 `bdc6d823` |
| `test/xaas/conference/sponsor_track_lifecycle_court_w984dn_test.exs` | tracked, clean | `docs/sjira/v26.10.6/plans/w984dn-sponsor-track.md` | SKIP — already landed (W984dq4/W650h6) |
| `test/xaas/operations/approval_castle_verb_schedule_authority_test.exs` | tracked, clean | `docs/sjira/v26.10.6/plans/w984dp2-ops-residue.md` | SKIP — landed by W984dq4 `bcf1371d` |
| `test/xaas/ultracode/process_group_court_test.exs` | tracked, clean | `docs/sjira/v26.10.6/plans/w984dj4-ultracode.md` | SKIP — landed by W650h6 |

## Verification ladder

- Strict fresh compile: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650h17 mix compile
  --force` EXIT=0 (warnings only, pre-existing: `RefusalLedgerExport.assert_all_pinned/1`
  etc.), fresh build root, ~20 min.
- New suites: `mix test test/xaas/bridges/w984dq3_durable_adapter_test.exs
  test/xaas/conference/registration_status_transition_court_w650y4_test.exs` →
  **10 passed**, 0 failures, EXIT=0 (1.8s).

## Disclosed incident (fix-forward, no force, no reset --hard)

First commit attempt `git commit -F msg` without pathspec swept 4 foreign staged files
from other lanes (shared-index collision; deleted-staged `w650h15-landing.md`/
`w650y3-cursor.md` + 3 foreign test files). Remediated by `git reset --soft HEAD~1`
(state-preserving, all foreign staged entries intact and left for their owners) then an
explicit-pathspec commit. Corollary commit message says "W984dq3 + W650y4" but the
commit contains only W984dq3 — W650y4 had already been landed by W650h16 `bdc6d823`
between my status check and commit; message left as-is (commits immutable), corrected
here.

Standing: **ALIVE** for W984dq3 court (compile EXIT=0 + 10/10 green on exact subject
`e483e854`); batch-2 landing complete — all 6 candidates landed or verified already
landed; nothing outstanding for this lane.
