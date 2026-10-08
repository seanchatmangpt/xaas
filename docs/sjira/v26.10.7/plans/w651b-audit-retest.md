# W651b — Live Audit Retest of the New Lane Classifier (W651 falsifier #1)

- **Date**: 2026-10-07
- **Lane**: W651b
- **Subject**: osx-clnr @ b61a596 ("recognize fan-out lane build roots (_build-lane*, target-lane*)"), built fresh in this lane at `~/osx-clnr/target-laneW651b/release/oclnr` (release, 52.5s build, exit 0). The session's MCP server binary is the stale pre-W651 build; all runs below are the NEW classifier via the CLI binary directly. MCP server NOT restarted.
- **Command shape**: `oclnr audit run --root <R> --ignore-recent-hours <H> --ocel-output /tmp/w651b-audit.jsonocel`

## Before / After (the falsifier)

| metric | old classifier (stale MCP, W651 pre-fix) | new classifier (b61a596 binary) |
|---|---|---|
| lane-root candidates over /Users/sac/xaas | **0** | **31** (`elixir lane build root (fan-out lease)`) |
| lane bytes visible | 0 | **11,361,620 KB ≈ 10.84 GiB** (`du -sk` over the 31 nominated roots) |

**Verdict: NOT a regression — the falsifier witnesses the fix.** 31 of the 31 on-disk
`_build-lane*` dirs were nominated with reason `lane build root (fan-out lease)`.

## Witness runs (real tails)

1. **Root=/Users/sac/xaas, `--ignore-recent-hours 0`** (gate off): 34 deletion candidates
   total = 3 non-lane (`.agents`, `.claude/tmp`, `_build`) + **31 lane roots**. OCEL log:
   `/tmp/w651b-audit.jsonocel`. Stdout capture: `/tmp/w651b-audit-stdout.txt`.
2. **Root=/Users/sac/xaas, gate on (h=1, 2, 3, 6, 12, 24, 72)**: **0 candidates at every
   window.** Recency suppression is applied at the PROJECT level
   (`src/integration/fs.rs:644` — `is_recently_active(path /* project root */, hours)`),
   so on an actively-worked checkout whose root dir has any file touched inside the
   window, all candidates including the lanes vanish together. Gate granularity =
   project root, not per-lane.
3. **Root = a lane root directly** (new b61a596 nomination site, `fs.rs:425`):
   - gate off (h=0), `_build-laneW984dj3`: **nominated**, 1 candidate, reason
     `lane build root (fan-out lease)`. (`_build-laneW650z3`, `_build-laneW984dj5b` same.)
   - gate on (h=1), same stale-by-dir-mtime lane (dir mtime 76 min): **still suppressed
     (0)**. `is_recently_active` (`fs.rs:349`) walks depth-6 and returns active if ANY
     FILE inside is newer than the window. `_build-laneW984dj3` contains 3,316 files
     with mtimes < 60 min (bulk-copied build trees carrying fresh interior mtimes), so
     the gate reads the lane as active. The fan-out law's "dir-mtime 60-min stale gate"
     is implemented as interior-file freshness, which on copy-preserved trees never
     opens.

## Protected running lanes (W984dj4 / dj5 / dj5b / 650k / 650w)

All 5 were nominated at h=0 (gate disabled), alongside the other 26. Ages at run time:
dj4 71 min, dj5 68 min, dj5b 44 min, 650k 59 min, 650w 32 min. Per the gate-on
behavior in run 2/3, none of the 5 would be nominated at h=1 — but neither would
anything else under the xaas root. No deletion was run in this lane; this is
scan-only. Nothing was deleted.

## Standing

- ALIVE (classifier nomination, scan-only): 31 lane candidates / ~10.84 GiB now visible
  to the audit layer where the previous build saw 0. Witnessed on the exact committed
  subject b61a596, built in-lane, real tails above.
- OPEN for W651's owner (boundary finding, not a W651b defect): the mtime gate is
  project-root-granular (`fs.rs:644`) and interior-file-based (`fs.rs:349`), so on an
  actively-worked checkout or a copy-preserved lane tree, `--ignore-recent-hours 1`
  suppresses lane visibility wholesale. Per-lane 60-min gating as written in the
  fan-out cleanup law is not yet reachable through `audit run --root <project>`.
- No commit made. Binary isolated in `~/osx-clnr/target-laneW651b` (lane lease; itself
  a `target-lane*` root the new classifier now names — verified by construction).
