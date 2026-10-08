# W651c — Lane-root recency gate: dir-mtime signal (fleet seal v26.10.7)

Standing: ALIVE (exact subject `osx-clnr@bcc53ee`, tests executed, pushed ff).
Lane: W651c. Repo: `/Users/sac/osx-clnr` (canonical checkout, no worktrees).
Base: `b61a596` (W651 classifier + W651b falsifier witness, pushed).
Head: `bcc53ee` — pushed ff `b61a596..bcc53ee` to `origin/main`.

## Task

From W651b's boundary finding (receipt `w651b-audit-retest.md`): the recency
gate for fan-out lane build roots was project-root-granular + interior-file-
based. A bulk-copied lane root (copy-preserved old mtimes on the dir, fresh
interior files) never gated open; gating on the project root suppressed ALL
lanes under an actively-worked repo.

## Change (handwritten, 2 files, +98/−9)

- `src/integration/fs.rs`
  - New `is_lane_root_recently_active(lane_root, hours)`: for lane roots
    (`_build-lane*`/`target-lane*` per W651's `is_lane_build_root_name`),
    recency = the lane root's **own directory mtime** only. Interior file
    freshness is deliberately excluded — a bulk copy preserves interior
    mtimes, and interior files say nothing about the lane being live. A live
    compile writes direct children continuously, moving the root dir mtime.
  - `scan_root` lane-root gate now calls it (`hours == 0` → never
    recently-active, matching the old `ignore_recent_hours > 0 &&` guard).
  - Non-lane candidates: existing interior-file project-root walk unchanged
    (call site in the visitor, `is_recently_active`, untouched).
- `src/domain/artifact.rs`
  - `CLASSIFIER_REVISION` 4 → 5 (ruleset semantics changed: which candidates
    survive the gate). `classifier_revision_is_5` test updated; the cache
    namespace prefix is now `scan-r5-` so pre-refinement scan caches cannot
    replay.

## Gate behavior before / after

| candidate | before | after |
|---|---|---|
| bulk-copied lane root, old dir mtime, fresh interior files | gate CLOSED (suppressed — interior walk sees "activity") | gate OPEN → nominated |
| live lane root, recent dir write | suppressed | suppressed (unchanged) |
| plain project root | interior-file walk | unchanged |
| lane root under actively-worked repo, root scanned as project | all its lanes suppressed by project-root interior freshness | judged per lane root dir mtime |

## Verification (real runs)

Two fresh target dirs, `cargo` from `~/.cargo/bin`:

1. `CARGO_TARGET_DIR=target-laneW651c cargo test --lib`
   → `test result: ok. 137 passed; 0 failed` (was 134 before lane; includes
   the 2 new scan-level tests).
2. `CARGO_TARGET_DIR=target-laneW651c-fresh2 cargo test` (full suite, fresh
   target dir) → all targets green except one **pre-existing** failure:
   `tests/pressure_monitor_tests.rs::live_build_process_cwd_excludes_its_target_dir`
   (3 passed / 1 failed). Classified as pre-existing by re-running it with
   pristine HEAD copies of my two touched files swapped in (still FAILED at
   HEAD state; my files restored afterward and re-verified by content swap
   back). Failure shape: `live_process_cwds` returns both `busy-app/target`
   and `idle-app/target` where only `busy-app/target` is expected. Not in
   this lane's file scope; disclosed, not fixed.

New/updated tests witnessed passing (target-laneW651c run):

```
test integration::fs::lane_root_scan_tests::scan_root_that_is_a_stale_lane_build_root_is_nominated_wholesale ... ok
test integration::fs::lane_root_scan_tests::bulk_copied_lane_root_with_old_dir_mtime_and_fresh_interior_files_is_nominated ... ok
test integration::fs::lane_root_scan_tests::live_lane_build_root_is_suppressed_by_recency_gate ... ok
test integration::fs::lane_root_scan_tests::lane_root_with_recent_dir_write_is_suppressed_despite_old_interior_files ... ok
test domain::artifact::lane_build_root_tests::classifier_revision_is_5 ... ok
```

(Existing stale-lane test still passes: it backdates the lane root dir too,
which is exactly the new signal.)

## Transport / transition record

- One `cargo test lane_root` CLI misuse (two filters) — operator error, no
  state change.
- Pristine-HEAD swap for failure classification: my files snapshotted to
  `/tmp`, HEAD versions swapped in, test rerun, my versions restored. No
  stash used (fanout law).
- Commit `bcc53ee` via `git commit -F /tmp/w651c-msg.txt`; push ff, never
  force. Only my two lane files staged (other lanes' in-flight edits
  untouched: AGENTS.md, CHANGELOG.md, README.md, scan_cache.rs, state.rs,
  autoclean.rs, snapshot.rs remain modified in the shared tree).

## Falsifiers

- Bulk-copied lane root with 2h-old dir mtime + fresh interior files must be
  nominated — witness test `bulk_copied_lane_root_with_old_dir_mtime_and_fresh_interior_files_is_nominated`.
- Lane root with recent dir write must stay suppressed — witness test
  `lane_root_with_recent_dir_write_is_suppressed_despite_old_interior_files`.
- Cache-invalidation: a pre-refinement scan cache (`scan-r4-`) must not
  replay — witness `classifier_revision_is_5`.

## Residue

- Lane build roots `target-laneW651c{,-fresh2}` left in `osx-clnr` (same
  precedent as W651/W651b's untracked lane roots; they are exactly the
  candidates the refined gate now nominates when stale).
- Pre-existing `pressure_monitor_tests::live_build_process_cwd_excludes_its_target_dir`
  failure left for its owning lane (out of W651c scope).
