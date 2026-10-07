# W292 Pre-Quiescence Snapshot — /Users/sac/xaas

Lane: W292 (integration) · v26.10.6 convergence · 2026-10-06
Read-only snapshot; no fixes, no git operations.

## 1. Files modified in last 15 minutes (lib/test/config/priv)

```
(none)
```

Empty — no lane is actively writing source files right now.

## 2. Active mix/beam processes

From `ps aux | grep -E "mix|beam" | grep -v grep` (18 beam.smp + 2 sh/node wrappers).
cwd and `-extra` args resolved per PID:

PIDs with cwd under /Users/sac/xaas — ACTIVE mix workloads:

| PID | cwd | command |
|---|---|---|
| 13506 | /Users/sac/xaas/deps/ash_typescript | `mix test test/xaas/ultracode/autonomic_profile_sense_test.exs test/xaas/ultracode/semantic_replay_test.exs test/xaas/ultracode/sj_program_registry_test.exs` |
| 10944 | /Users/sac/xaas | `mix test test/xaas/ultracode` |
| 32266 | /Users/sac/xaas | `mix test test/xaas/ultracode` |
| 22706 | /Users/sac/xaas | `mix test` (full suite) |
| 33841 | /Users/sac/xaas | `mix run -e Application.put_env(:xaas, :marketplace_catalog_source, ...) --no-halt` |
| 96366 | /Users/sac/xaas | `mix test test/xaas/ultracode` |
| 39495 | /Users/sac/xaas | `mix test test/xaas/chicago test/xaas/sjira test/xaas/ultracode test/mix` |
| 33934 | /Users/sac/xaas | `mix test test/xaas/ultracode/semantic_jira_e2e_test.exs` |

Other beams (not on this checkout): 16690, 42232, 15849 (ash_pplan / ash_pplan/deps/sparql);
42030, 42108, 40053, 41296, 40736, 39994 (cwd unreadable / exited mid-inspection).

## 3. Lane build roots pending cleanup

```
_build-laneW125
_build-laneW141
_build-laneW177
_build-laneW212
_build-laneW262
_build-w136
_build-w150
```

7 roots total: 5 `_build-laneW*` + 2 `_build-w*`.

## Verdict: ACTIVE

Blockers:

1. **8 non-coordinator mix processes running on /Users/sac/xaas** (PIDs 13506, 10944,
   32266, 22706, 33841, 96366, 39495, 33934) — mostly `mix test` runs, including one
   full-suite `mix test` (22706) and one long-lived `mix run --no-halt` server (33841).
2. **7 orphaned lane build roots** pending coordinator cleanup
   (`_build-laneW125/141/177/212/262`, `_build-w136`, `_build-w150`).

Not blockers (cleared conditions):

- No source files under lib/test/config/priv modified in the last 15 minutes.
- Beams on other checkouts (ash_pplan, deps) are not this repo's convergence work.

Note: test beams share the shared `_build` on this canonical checkout — concurrent
`mix test` runs may be contending on it; the full-suite run (22706) is the long pole.
