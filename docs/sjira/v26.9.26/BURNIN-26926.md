# BURNIN-26926 — 1-hour xaas ultracode burn-in + OCEL v2 validation

- **standing:** PARTIAL_ALIVE (steps 1–9 DONE head-verified; loop stalled on the cron defect below)
- **state surface:** `/Users/sac/xaas/tmp/burnin-20260926/STATE.md` (14 steps) + `loop.ndjson` (telemetry)
- **work surface:** `/Users/sac/xaas/tmp/burnin-20260926/repo` (real git repo, seeded `5a653bc`)

## Goal

One real zcode worker per tick driven through `Xaas.Ultracode.WaveLoop.tick/1`
for a 1-hour burn-in over 14 small real steps in the scratch repo, validating
the OCEL v2 event path (per-tick receipts, heartbeats, head-verified closes)
end to end. When every STATE row is DONE the loop records `:complete`.

## History

| ts | standing | note |
|---|---|---|
| 2026-09-26T23:20Z | UNKNOWN | 14-step STATE seeded (`/Users/sac/xaas/tmp/burnin-20260926/STATE.md`, work surface seeded at `5a653bc`, driver pid 70127); steps 1–14 defined, all pending |
| 2026-09-26T23:20Z → 2026-09-27T01:16Z | PARTIAL_ALIVE | steps 1–9 DONE via driver-driven wave-loop ticks 1–13 (redispatches where early fences refused); each close sealed a head-verified `partial_alive` worker receipt (`loop.ndjson`: 13 lines, last worker_completed step 9 = tick 13, epoch `0baad87b`, sealed 2026-09-27T01:16:21Z; STATE rows carry receipt epoch + exit=0 dispatch log per step) |
| 2026-09-27T01:1xZ | PARTIAL_ALIVE | phase B worktree carry-through cycles 0+1 landed (commits `533cb3b`, `118f17a`; `WT-LEDGER.md` records the carried worktree state) |
| 2026-09-27T01:16Z | BLOCKED | **DEFECT:** the wave-loop cron never fired — queue `ultracode_wave_loop` was never cron-scheduled, so telemetry stops at the last driver-driven tick (`loop.ndjson` last line 2026-09-27T01:16:39.101890Z) and the queue holds 2 rows ever (job 8235 completed, job 9255 zombie, cancelled). Repair assigned to lane 1 (wave-loop cron repair) in the 10-lane wave of 2026-09-27T03:48Z |
| pending | UNKNOWN | **REMAINING:** steps 10–14 (ledger-depth, verify-script, provenance-block, sums-table, closeout) finish autonomously once the cron repair lands; then the final `validate.sh` re-run closes this ticket |

## Falsifier

A burn-in is only closed when `loop.ndjson` grows past 01:16Z without the
driver (cron-fired ticks), steps 10–14 flip DONE with head-verified receipts,
and the final `validate.sh` re-run exits 0 on the completed STATE.

## History (continued)

| ts | standing | note |
|---|---|---|
| 2026-09-27T05:45Z | BUILD_BROKEN | cron fired but workers had NO xaas-execution tools — server relaunch (04:01Z) omitted INTERNAL_API_TOKEN; MCP initialize 401; ticks 14–18 worker_unclosed |
| 2026-09-27T05:52Z | PARTIAL_ALIVE | server relaunched WITH token + loop env (pid 99235); pool 5→10; tick 19 (oban 20628) wedged 80 min post-claim, no spawn — cancelled via SQL (typed UNKNOWN root cause; watchdog ordered P0.1) |
| 2026-09-27T06:45Z | ALIVE | tick 20 (epoch e71a1843) ran clean end-to-end; steps 10–14 DONE via ticks 20–23, all head-verified; **burn-in COMPLETE: 14/14**; final validate.sh: **52/52 runs OCEL v2 valid**; loop recorded :complete |
