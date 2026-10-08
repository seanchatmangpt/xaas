# W651d — Per-lane recency gate on the parent-project scan path

- **Lane**: W651d (v26.10.7 fleet seal)
- **Subject**: osx-clnr @ `7b12d2e` — "fix(integration): W651d per-lane recency
  gate on the parent-project scan path", committed on `main` and **pushed**
  (`bcc53ee..7b12d2e main -> main`, ff, fetch-first).
- **Date**: 2026-10-07, ~16:15–17:05 PDT
- **Fixes**: the W651c2 falsifier (`w651c2-gate-falsifier.md`) — W651c's
  refinement (`is_lane_root_recently_active`) only fired on the
  scan-root-IS-a-lane-root path; on the parent-project path the whole-nominated
  lane candidates were suppressed by the PROJECT root's recency
  (`is_recently_active(project_root)` at fs.rs:670), so one fresh compile
  anywhere suppressed every lane.

## Diff (3 files, 112 insertions, 8 deletions)

1. `src/integration/fs.rs` — the fs.rs:670 suppression site is now
   per-candidate: a candidate whose file name passes `is_lane_build_root_name`
   is judged by `is_lane_root_recently_active(candidate_path, hours)` (the lane
   root's OWN dir mtime); non-lane candidates keep the project-level
   `is_recently_active` rule. Non-lane semantics unchanged.
2. `src/domain/artifact.rs` — `CLASSIFIER_REVISION` 5 → 6 (gate semantics
   changed; `scan_cache_revision_prefix()` now `scan-r6-`, revision unit test
   renamed `classifier_revision_is_6`).
3. `tests/integration_tests.rs` — new
   `test_parent_project_scan_lane_gate_splits_stale_from_fresh`: actively-
   worked elixir project (fresh root mtime, fresh `target/`), one stale lane
   root (dir mtime aged to 2020-01-01, INTERIOR file left fresh — interior
   freshness must not gate a lane), one fresh lane root. Asserts stale lane
   nominated with reason `elixir lane build root (fan-out lease)`, fresh lane
   suppressed, fresh non-lane `target/` keeps project-level suppression;
   `hours=0` nominates both lanes.
4. (disclosed unblock fix, same file as #2) pre-existing broken doctest
   `is_traversal_barrier_name` — missing `is_lane_build_root_name` import;
   failed to COMPILE at bcc53ee too (witnessed in a clean `git archive
   bcc53ee` build in `/tmp/w651d-base`). Minimal import fix only.

## Test receipt (cargo test x2, fresh target dirs)

- `CARGO_TARGET_DIR=target-laneW651d` and `target-laneW651d-r2`, both fresh.
- Run 1 (`--no-fail-fast`): 28/28 integration_tests incl. the new gate test
  (`test result: ok. 28 passed; 0 failed`); lib 137 ok; doctests
  **190 passed; 0 failed** (after the import fix; at base it was 186 passed /
  1 failed-to-compile).
- Run 2 (`target-laneW651d-r2`, fresh, `--no-fail-fast`): same — everything
  green except one binary.
- **Sole remaining failure, pre-existing (not session-introduced)**:
  `pressure_monitor_tests::live_build_process_cwd_excludes_its_target_dir`
  (`tests/pressure_monitor_tests.rs:109`, left=both targets, right=busy only).
  Witnessed failing identically at base `bcc53ee` in the clean archive build
  (exit-identical `left`/`right` vectors). Process-scan race, unrelated to the
  gate; left for its owner.

## Live-tree before/after (release binary at 7b12d2e, root=/Users/sac/xaas)

```
$ CARGO_TARGET_DIR=target-laneW651d cargo build --release   # exit 0, 47.03s
$ ./target-laneW651d/release/oclnr audit run --root /Users/sac/xaas \
    --ignore-recent-hours 1
Found 21 Deletion Candidates:      # ALL are lane roots, ALL dir-mtime > 60 min
$ ./target-laneW651d/release/oclnr audit run --root /Users/sac/xaas \
    --ignore-recent-hours 0
Found 44 Deletion Candidates:      # 41 lane roots nominated (gate off)
```

**Before (bcc53ee, W651c2 receipt): h=1 → 0 candidates (all-or-nothing).**
**After (7b12d2e): h=1 → 21 candidates, the exact stale/fresh split.**

The nominated 21 at h=1 are precisely the lanes whose root dir mtime is
15:47:40 PDT or earlier (scan ran ~16:55; cutoff ≈ 15:55); every lane fresher
than the cutoff (15:55:24 `_build-laneW650w2` through 16:49:00
`_build-laneW984dq2-fresh1`, ~20 lanes) was suppressed. Boundary check: latest
nominated 15:47:40, earliest suppressed 15:55:24 — clean cut at the 60-min
window. No non-lane candidate appeared at h=1 (project-level rule preserved).

## Standing

- Parent-project scan, hours>0, per-lane stale/fresh split: **ALIVE** on the
  live tree (this commit's release binary).
- Gate-off (hours=0) whole-root nomination: ALIVE (41 lanes / 44 total).
- Non-lane suppression semantics (project-level recency): ALIVE, unchanged.
- Pre-existing pressure_monitor failure: BLOCKED(pre-existing) — owner
  W651-pressure or next gate lane; falsifier documented above.
- Doctest compile failure at base: fixed in this commit (190/190).

## Cleanup debt (per fanout cleanup law)

`target-laneW651d` and `target-laneW651d-r2` remain in ~/osx-clnr (~800 MB
total, freshly written). Lane target roots are now correctly
gate-suppressed by this very fix; integration should delete them at seal time
alongside `target-laneW651`, `target-laneW651b`, `target-laneW651c2` from
prior lanes. /tmp artifacts: `/tmp/w651d-*.txt`, `/tmp/w651d-base` (bcc53ee
archive), `/tmp/w651d-msg.txt`, `/tmp/w651d-run1.log`.
