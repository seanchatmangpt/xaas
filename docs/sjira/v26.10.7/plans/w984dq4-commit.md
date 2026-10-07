# W984dq4 — landed-uncommitted sweep receipt

Lane W984dq4, repo `/Users/sac/xaas`, branch `feat/playwright-surface`. Date 2026-10-07.
Task: land completed depth-probe lanes sitting uncommitted in the shared checkout.

## Gate (real output)

- Strict compile fresh root: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dq4 mix compile --force` → **EXIT=0** (209 dep apps, "Generated xaas app").
- Staged test batch (5 files, one batch): **25 passed, 0 failed**, EXIT=0 (1.4s).
  Files: sponsor_track_lifecycle_court_w984dn, w984cy4_override_decision_court, approval_castle_verb_schedule_authority, research_runtime/closure/coordinator, process_group_court.

## Staged table

| lane | file | receipt on disk | outcome |
|---|---|---|---|
| W984dn | `test/xaas/conference/sponsor_track_lifecycle_court_w984dn_test.exs` | `w984dn-sponsor-track.md` | landed by concurrent lane W650h6 in 9ec12305 mid-flight |
| W984dp2 | `test/xaas/operations/approval_castle_verb_schedule_authority_test.exs` | `w984dp2-ops-residue.md` | **landed this lane, commit bcf1371d** |
| W984dj4 | `test/xaas/ultracode/process_group_court_test.exs` | `w984dj4-ultracode.md` | landed by W650h6 in 9ec12305 mid-flight |
| W984cy2 | `test/xaas/research_runtime/closure/coordinator_test.exs` | `w984cy2-families-probe.md` | landed by W650h6 in 9ec12305 mid-flight |
| W984cy4 | `test/xaas/governance/w984cy4_override_decision_court_test.exs` | `w984cy4-gov-73.md` | landed by W650h6 in 9ec12305 mid-flight |

Receipts `w984dn-sponsor-track.md` and `w984dp2-ops-residue.md`: tracked on HEAD (w984dp2 via bcf1371d; w984dn via 9ec12305). cy2/cy4/dj4 receipts were already tracked pre-sweep.

## Exclusions

- Batch-2 commit not needed: cy2/cy4/dj4 files were committed by the concurrent W650h6 lane (9ec12305) between my batch-1 add and commit — all 7 sweep files verified `git ls-files`-tracked on HEAD before push.
- No lib/ changes, no force push, pathspec-only commits.

## Standing

ALIVE for the sweep subject: compile EXIT=0 fresh root + 25-test green batch witnessed on the working tree, all 7 files tracked on HEAD at bcf1371d, pushed ff. Falsifier: any of the 5 test files failing on a fresh clone of bcf1371d.
