# W650h20 — SelfDigest family completion (2 depth courts)

Branch `feat/playwright-surface`, HEAD at write time `983ca0ae`. No commit (lane law:
coordinator owns transitions).

## Fresh census (this lane, on-disk reads)

Family `lib/xaas/self_digest/` = 9 modules, 204 LOC:
admission 18, evidence 27, gap 23, observation 11, promotion 17, receipt 31, replay 28,
shadow 21, work 28. Direct tests before this lane: only
`test/xaas/self_digest/promotion_pipeline_depth_test.exs` (W650w/W650h11, 5 tests, pipeline-level).

## Selection

Picked the 2 state-bearing modules NOT covered by the promotion-pipeline court:

- **Gap** (`gap_depth_test.exs`): the landed court constructs a gap only
  transitively inside promote/4; `rank/1` scoring and `admit/refuse` status
  transitions had zero direct coverage.
- **Work** (`work_depth_test.exs`): the landed court builds a Work only as
  a promote/4 argument; stable-id derivation, acceptance:=falsifier
  binding, and authority defaulting had zero direct coverage.

Shadow/Replay/Receipt/Admission/Promotion were excluded as overlap with the
landed court (its test 4 covers replay mismatch + broken chain; test 5
covers receipt determinism + shadow one-shot; tests 2/3 cover admission
refusals). Remaining thin remainder (Observation 11 LOC: constructor +
`exact_subject?/2`; Evidence already exercised via landed court + gap court)
typed disposition: **UNSUPPORTED(depth-thin)** — pure constructors with no
independent state machine beyond what courts already pin transitively.

## Courts (10 tests, all real-module, no mocks)

- `test/xaas/self_digest/gap_depth_test.exs` — 5 tests: admit status
  transition, typed refuse status, rank formula incl. nil coercion, rank
  ordering (dependency penalty sign), admit-replaces-not-appends.
- `test/xaas/self_digest/work_depth_test.exs` — 5 tests: from_gap
  derivation (subject/acceptance/authority/state), stable id deterministic
  over (subject, claim) only, distinct claims mint distinct ids, explicit id
  override, construct stored unadulterated + callable.

Each test names its mutant class in a comment.

## Execution (real gate, actual output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650h20 \
  mix test test/xaas/self_digest/gap_depth_test.exs test/xaas/self_digest/work_depth_test.exs --trace
```

Result: `10 passed, 0 failures`, EXIT=0 (fresh build root, full compile,
seed 770133). Mock gate not rerun (tests add no mocks; pure ExUnit + real
modules).

## Build root

Deletion of `_build-laneW650h20` attempted and **BLOCKED(cleanup-permission)**
— `rm -rf` denied by the permission system in this session. Directory left
on disk for coordinator deletion at integration (same disposition as W650k6).

## Standing

- Gap depth court: **ALIVE** (observed execution, 5/5 green, exact files above).
- Work depth court: **ALIVE** (observed execution, 5/5 green).
- Observation/Evidence standalone depth courts: **UNSUPPORTED(depth-thin)**
  — covered transitively; no independent state machine left unpinned.

## Falsifiers (regression signal)

- `mix test test/xaas/self_digest/gap_depth_test.exs` goes red on rank-formula
  drift, status-shape drift, or admit-accumulate regression.
- `mix test test/xaas/self_digest/work_depth_test.exs` goes red on stable-id
  drift (mutable fields entering the digest), authority default drift, or
  acceptance-binding loss.
