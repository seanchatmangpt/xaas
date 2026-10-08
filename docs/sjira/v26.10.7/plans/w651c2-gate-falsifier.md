# W651c2 — Live gate falsifier: lane-root recency gate over real xaas lane roots

- **Lane**: W651c2 (v26.10.7 fleet seal). Subject CLI: osx-clnr @ `bcc53ee`
  ("fix(integration): W651c lane-root recency gate judges the lane root's own dir mtime"), pushed.
- **Date**: 2026-10-07 16:09–16:15 PDT
- **Method**: release build of `bcc53ee` (cargo, lane-isolated target dir), then
  `oclnr audit run --root /Users/sac/xaas` at `--ignore-recent-hours 1` and `0`,
  plus `--verbose` trace and source read to locate the deciding gate.

## Commands (real tails)

```
$ cd ~/osx-clnr && git log --oneline -1
bcc53ee fix(integration): W651c lane-root recency gate judges the lane root's own dir mtime
$ CARGO_TARGET_DIR=target-laneW651c2 cargo build --release
    Finished `release` profile [optimized] target(s) in 42.88s   (exit 0)
$ ./target-laneW651c2/release/oclnr audit run --root /Users/sac/xaas --ignore-recent-hours 1
Auditing disk | phase=scanning disk | files=19173 dirs=1471 seen=1.21 GB ... skipped=265 errors=0
  Projects detected:   4
Found 0 Deletion Candidates:
$ ./target-laneW11-lane... (hours=0)
Found 34 Deletion Candidates:   # 31 of them _build-lane* under /Users/sac/xaas
  • /Users/sac/xaas/_build-laneW650V2 (elixir lane build root (fan-out lease))
  • ... (31 lane roots total, all 31 nominated under gate-off)
$ (same, --verbose, hours=1)
Found 0 Deletion Candidates:    # verbose trace shows lanes fully walked, then suppressed
```

## Witness: the designed split did NOT happen — still all-or-nothing

11 of 31 enumerated lane roots had **dir-mtime age > 60 min** at scan time
(16:09–16:11 PDT) and were the designed nominees at `hours=1`. All 31 were
suppressed (0 candidates).

| root | dir-mtime (PDT) | age @scan | bytes (du) | nominated @h=1 | nominated @h=0 |
|---|---|---|---|---|---|
| /Users/sac/xaas/_build-laneW984dj3 | 14:41:33 | 91 min | 425.76 MB | N | Y |
| /Users/sac/xaas/_build-laneW984dj4 | 14:45:41 | 87 min | 425.76 MB | N | Y |
| /Users/sac/xaas/_build-laneW984dj5 | 14:48:28 | 84 min | 425.76 MB | N | Y |
| /Users/sac/xaas/_build-laneW984di2 | 14:52:43 | 80 min | 425.76 MB | N | Y |
| /Users/sac/xaas/_build-laneW650i | 14:53:03 | 79 min | 425.77 MB | N | Y |
| /Users/sac/xaas/_build-laneW984dj2b | 14:54:06 | 78 min | 425.77 MB | N | Y |
| /Users/sac/xaas/_build-laneW984dl | 14:55:54 | 77 min | 425.77 MB | N | Y |
| /Users/sac/xaas/_build-laneW984dj6 | 14:56:38 | 76 min | 425.76 MB | N | Y |
| /Users/sac/xaas/_build-laneW650k | 14:57:13 | 75 min | 425.76 MB | N | Y |
| /Users/sac/xaas/_build-laneW984dm | 14:58:42 | 74 min | 425.76 MB | N | Y |
| /Users/sac/xaas/_build-laneW650r | 15:09:51 | 63 min | 425.76 MB | N | Y |
| _build-laneW984dj5b | 15:13:56 | 59 min | 425.76 MB | N (fresh) | Y |
| _build-laneW984dj4-r2 | 15:17:33 | 55 min | 425.76 MB | N | Y |
| _build-laneW650w | 15:24:34 | 48 min | 425.77 MB | N | Y |
| _build-laneW650y | 15:28:58 | 43 min | 425.77 MB | N | Y |
| _build-laneW650f2 | 15:29:31 | 43 min | 425.77 MB | N | Y |
| _build-laneW984dj6b | 15:31:12 | 41 min | 425.77 MB | N | Y |
| _build-laneW650z3 | 15:33:37 | 39 min | 425.77 MB | N | Y |
| _build-laneW984do | 15:34:12 | 38 min | 425.77 MB | N | Y |
| _build-laneW984dn | 15:34:35 | 38 min | 425.77 MB | N | Y |
| _build-laneW650i-r2 | 15:34:52 | 38 min | 425.76 MB | N | Y |
| _build-laneW984dj5b2 | 15:43:42 | 29 min | 424.35 MB | N | Y |
| _build-laneW984dj7 | 15:45:10 | 27 min | 357.21 MB | N | Y |
| _build-laneW650V2 | 15:45:58 | 26 min | 425.77 MB | N | Y |
| _build-laneW984dp2 | 15:47:40 | 25 min | 425.76 MB | N | Y |
| _build-laneW650y2 | 15:55:53 | 17 min | 359.27 MB | N | Y |
| _build-laneW650w2 | 15:55:24 | 17 min | 357.22 MB | N | Y |
| _build-laneW650q2b | 16:01:32 | 11 min | 357.22 MB | N | Y |
| _build-laneW650z4 | 16:08:16 | 4 min | 243.50 MB | N | Y |
| _build-laneW984dp3 | 16:09:19 | 3 min | 165.49 MB | N | Y |
| _build-laneW984dp4 | 16:10:20 | 2 min | 26.28 MB | N | Y |

(31 rows = the roots present at first enumeration; two later spawns
`_build-laneW650h5` and `_build-laneW984dj5b2c` appeared at 16:12 and are
post-witness, not tabled. Fleet total 34 at receipt-write time.)

**@h=1: 0 nominated / 11 stale (>60 min) — designed split absent.**
**@h=0: 31/31 nominated (plus `_build`, `.agents`, `.claude/tmp`; 34 candidates total).**
Lane bytes under gate-off: **12,243,156 KB ≈ 11.67 GiB** (du of the 31+2 roots).
vs W651b pre-refinement witness (31 gate-off / 0 gate-on at project granularity):
**unchanged** — same all-or-nothing split. **This is the regression finding for
W651c's owner.**

## Root cause (source, bcc53ee)

The W651c refinement (`is_lane_root_recently_active`, src/integration/fs.rs:406)
judges the lane root's own dir mtime — but only on the **scan-root-IS-a-lane-root**
path (fs.rs ~445). When the scan root is the parent project (/Users/sac/xaas),
lanes are nominated as whole-root candidates from the project's snapshot
(src/domain/artifact.rs:1455–1476, elixir/erlang; 1434 for rust) and the
recency suppression applied to that candidate batch is fs.rs:670:

```rust
let recently_active = args_snapshot.ignore_recent_hours > 0
    && is_recently_active(path, args_snapshot.ignore_recent_hours);
```

`path` there is the **project root**, not the lane root — one fresh
`mix compile` anywhere in the repo makes `is_recently_active(/Users/sac/xaas)`
true and suppresses every `_build-lane*` candidate from that project's
snapshot. The per-lane gate exists but is not wired into the
project-snapshot nomination path. (Verified: h=1 verbose trace walks every
lane's interior then drops all candidates; only the project root's
recency was consulted.)

## Fix direction (for W651c owner, not implemented by this lane)

In the fs.rs:670 suppression, per-candidate: when the candidate path's file
name passes `is_lane_build_root_name`, gate on
`is_lane_root_recently_active(candidate_path, hours)` instead of the project
root's `is_recently_active`. Gate path candidates individually.

## Standing

- CLI build: ALIVE (bcc53ee, release, exit 0).
- hours=0 nomination over real lane roots: ALIVE (31/31 + 3 non-lane candidates).
- hours=1 per-lane split: **REFUTED** on this subject — gate remains
  project-granularity all-or-nothing under the parent-project scan path.
- Cleanup: `target-laneW651c2` in ~/osx-clnr **NOT deleted** — `rm -rf` denied
  by session permission, and the shared oclnr workflow state is held at
  PLAN_READY by another lane (cannot start a scan/plan without clobbering
  it). Left on disk (~420 MB, freshly-written dir mtime → correctly
  suppressed by the gate anyway); owner should clean at integration per the
  fanout cleanup law.
- No commits made; only this receipt written.
