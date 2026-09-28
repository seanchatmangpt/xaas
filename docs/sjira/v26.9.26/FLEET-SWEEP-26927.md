# FLEET-SWEEP-26927 — fleet-wide inventory via xaas ultracode (10+ concurrent workers)

- **standing:** ALIVE (11/11 reports written, 14/14 runs OCEL-v2 valid)
- **operator order:** "upgrade everything to the most recent including docker, act, etc" → "search all projects" → "wait, this is a perfect task for xaas and it to run 10 agents in ultracode"
- **surface:** `/Users/sac/xaas/tmp/fleet-sweep/surface` (seed `63ceb2d`, reports commit `1b58c84` + `c7b1441`)
- **mechanism:** 14 runs (11 first wave + 3 half-pace retries) created via `Xaas.Ultracode.Run` and dispatched **concurrently** through `Xaas.Ultracode.Dispatch` with `extra_env: %{"XAAS_SWEEP" => "1"}` — real claims, leases, gate admissions, receipts, OCEL egress

## Enabling fabric changes (this wave)

| change | commit | proof |
|---|---|---|
| provider pool 5 → 10 | `6015388`-era config | 11 concurrent claims admitted |
| typed read-only sweep profile `XAAS_SWEEP=1` | `360a867` | witnessed: sweep git-log/cat outside worktree ALLOW; sweep commit DENY; sweep `.zcode` DENY; no-sweep DENY |
| per-epoch lease keys + gate/lease keyed read | `c2adb24` (zcode-cli) + `0a3e5d7` | 11 workers, ONE shared surface, zero lease_conflict |

## Results

- 11 reports in `surface/reports/step-1..11.md`, 158 inventory rows (2 duplicated entries from the coordinator's repo list)
- verdicts: **48 CURRENT, 76 DRIFTED, 8 UNKNOWN** (rest of rows non-standard verdict wording)
- first pass 8/11 through a z.ai rate-limit storm; 3 re-dispatched at half pace → 3/3

## Measured rate limits (operator asked for stats, not guesses)

- `model_request_failed` events across all 11 workers: **43 total** (an earlier "500+ hits" grep counted substring matches in echoed context — wrong instrument, retracted)
- bursts: **16 failures/min** (04:57Z) and **10/min** (05:03Z) at concurrency 11 — every one absorbed by client retries (maxAttempts 6); zero worker deaths from rate limits
- half pace (3-wide) after the drain: 0 failures

## Defects found while running

1. fleet-validate wrapper validated directories (`--out` is a directory arg) — wrapper bug, fixed; production `xaas.ocel_validate` is fail-closed (exit 1) — verified
2. wave_loop tick 19 (oban 20628) wedged 80 min post-claim with no spawn; cancelled via SQL; tick 20 ran clean — root cause of the wedge typed UNKNOWN, needs a dispatch-side watchdog (see NOT-DONE)

## NOT-DONE

- tick-19 wedge root cause (typed UNKNOWN): add a bounded watchdog/timeout around WaveLoop tick dispatch
- 26 rows carry non-standard verdict wording; normalize on a follow-up pass
- per-repo upgrade PRs (the sweep is the demand signal; work orders not yet created)

## History (continued)

| ts | standing | note |
|---|---|---|
| 2026-09-27T01:00Z | PARTIAL_ALIVE | P0.1/P0.3/P0.4 landed (e12e117): Oban.Lifeline (orphan ticks auto-rescued >75min), work-conserving tick chaining, adaptive dispatch width (10-min pressure window). Root cause of the 80-min wedge typed: BEAM kill mid-tick + no Lifeline — job orphaned `executing`, not a Dispatch deadlock |
| 2026-09-27T01:10Z | PARTIAL_ALIVE | P0.2 SIGKILL regression landed: dead worker settles typed (dispatch_refused family), epoch reaped, slot free without SQL. wave_loop 47/47 |
| 2026-09-27T01:15Z | BUILD_BROKEN(external) | semantic_replay/ggen toolchain: shim→1.18 mix loads Hex fine (v2.5.1 verified); corrupt-atom-table persists in COLD replays (fresh work_dir, no .tool-versions → shim falls to global toolchain). Filed as producer fix: semantic_crown must pin the work_dir toolchain or ship .tool-versions into the archive. 12 ultracode failures all in this family + RemoteRelay load-flake |
| 2026-09-27T01:30Z | PARTIAL_ALIVE | Dogfood cycle 1: toolchain work order dispatched via fabric; worker delivered complete patch + honest BLOCKED (gate lawfully fenced xaas-tree edits — work-order boundary design error, next orders must set lease worktree = target repo). Coordinator applied patch; acceptance FAILED (corrupt-atom-table persists under explicit pin → third resolution layer, typed UNKNOWN with 3 falsified fixes: Hex 2.5.1 reinstall, deps re-fetch, _build rebuild). Patch reverted (no fake success). Residual = top edge for next run: instrument the replayed context (`which mix; mix --version` echo inside ggen/2) before another fix |
| 2026-09-27T13:57Z | PARTIAL_ALIVE | merge-day: sole-copy fix (SemanticCrown ASDF pin patch, surface e48118b) applied to lane2 and acceptance-run: same corrupt-atom-table family, 9/13 fail (semantic_replay, 616s, pre-merge baseline) — patch reverted, no fake success; fourth falsified resolution layer (explicit pin from ggen_dir with .tool-versions present). Residual stands as top edge; suite environmentally BLOCKED for merge gate (typed exclusion, wave_loop 47/47 + cs2/census 13/13 green on merged main e499e10e)
