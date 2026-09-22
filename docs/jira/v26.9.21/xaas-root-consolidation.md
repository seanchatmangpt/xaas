# XaaS Root Consolidation — all `~/xaas*` trees merged into `~/xaas`

## Summary

Operator order (2026-09-21): "all of the xaas* need to be merged into ~/xaas,
there should never be different folders." The ultracode runtime currently
spans five top-level trees; they collapse into the repo root under two
gitignored directories (`/worktrees/`, `/tmp/`). Capabilities must be moved
and completed — not a git-history merge; a live-path consolidation validated
Chicago-style before tonight's 8-hour campaign.

## Path map (the only legal mapping)

| old | new |
|---|---|
| `/Users/sac/xaas-worktrees` | `/Users/sac/xaas/worktrees` |
| `/Users/sac/xaas-tmp` | `/Users/sac/xaas/tmp` |
| `/Users/sac/xaas-wt2` (2 main-repo worktrees + loose logs) | `/Users/sac/xaas/worktrees/wt2` |
| `/Users/sac/xaas-wt3` (empty) | deleted |

Historical evidence (wave-receipts dirs, ledger/receipt quotes, history
tables in jira tickets, PROGRESS.md entries) keeps old paths verbatim —
rewriting evidence is falsification. Only ACTIVE surfaces change.

## Preconditions (already executed by coordinator)

- phx.server STOPPED (beam pid 55485 killed) — Oban clock frozen.
- Zombie epochs confirmed: 6 `running` (unleased) + 1 `expected` + 1 with
  lease expired 2026-09-18 — no live worker processes (pgrep clean).
- Branch `feat/xaas-root-consolidation` checked out; `.gitignore` gained
  `/worktrees/` and `/tmp/`.
- No harness automations exist (CronList empty).

## Slices (10 default-agent wave, disjoint file ownership)

| agent | slice | owns |
|---|---|---|
| A1 | config | config/dev.exs (8 refs), config/{config,test}.exs sweep |
| A2 | repos libs | lib/xaas/ultracode/repos.ex, target_suites.ex + tests |
| A3 | wave loop | lib/xaas/ultracode/wave_loop.ex, wave_loop/state.ex + tests |
| A4 | tests | test/xaas/ultracode/autonomic_*, semantic_crown_test |
| A5 | docs 1 | eight-hour-run.md, FAILOVER-RUNBOOK.md active blocks |
| A6 | docs 2 | multi-repo-run.md, .claude/workflows/errc-closure-v26-9-20.js |
| A7 | physical move | mv all trees, `git worktree repair` (main + aps), registry JSON rewrite, ~/.zcode/failover state check |
| A8 | zombie reap | DB: reap 7 zombie epochs per zombie-runs-cleanup ticket |
| A9 | external sweep | crontab, LaunchAgents, shell rc, ~/.zcode configs — old-path refs |
| A10 | validator | falsifier grep, compile --force, format, ultracode+zcode_plugin suites, close gaps |

## Key Invariant(s)

- Git operations serialize through the coordinator: agents NEVER commit.
- Mix gates go through `.claude/workflow-compile-lock.sh` (FAILOVER-RUNBOOK §2).
- No agent recreates directories at old paths; failures are reported, not patched.
- Old dirs must be GONE at the end: `ls -d /Users/sac/xaas-worktrees
  /Users/sac/xaas-tmp /Users/sac/xaas-wt2 /Users/sac/xaas-wt3` → all missing.

## Falsifiers

- Any active surface (config, lib, test, scripts, runbooks, registry,
  external schedulers) still referencing an old path.
- `git -C /Users/sac/xaas worktree list` showing prunable/broken entries.
- aps clone or any run worktree unhealthy after the move.
- Campaign smoke failing at the new paths.

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-21T17:15-07:00 | PARTIAL_ALIVE | feat/xaas-root-consolidation @ 2ec5fdb+ | inventory complete; beam down; zombies confirmed; branch cut | 10-agent wave → gates → smoke → merge → 8h launch |
