# W167 — Postgres connection saturation in test runs (FATAL 53300)

Lane: W167, v26.10.6 convergence. Repo: /Users/sac/xaas.
Scope: test-env only. Prod config untouched. No git operations.

## Diagnosis (real output, 2026-10-06)

- `psql -h localhost -U postgres -d xaas_dev -c "SELECT count(*) ..."`:
  **failed with the bug itself** — `FATAL: sorry, too many clients already`
  (53300). Server was saturated at census time.
- `lsof -i :5432`: 403 lines; **202 postgres / 200 beam.smp** sockets.
  max_connections exhausted exactly.
- Per-PID: 6 beam VMs; 4-5 with cwd `/Users/sac/xaas`, ~41 connections each;
  the rest from other projects (~21 and ~15).
- `SHOW max_connections` → **200** (postgresql@14 default,
  `/opt/homebrew/etc/postgresql@14/postgresql.conf:65`).
- Server log (`/opt/homebrew/var/log/postgresql@14.log`) shows a burst of
  `FATAL: sorry, too many clients already` at census time.

## Root cause

Concurrent-lane artifact, as suspected (W163/W120): each `mix test` lane
eagerly opens `pool_size` per repo, and the pools are sized as if only one
lane ever runs:

| pool | per-lane (before) |
|---|---|
| Xaas.LegacyRepo (Sandbox) | 20 |
| Xaas.Repo (Sandbox) | 20 |
| ash_graphlaw | 2 |
| ash_affidavit | 2 |
| **total** | **44** |

Observed ~41/lane against max_connections=200 → saturation at ~4 concurrent
xaas lanes; the 5th lane gets 53300. Other beam processes on the box held
~36 more.

## Closure (config/test.exs only)

Both Sandbox pools reduced 20 → 10:

- per-lane demand: 10 + 10 + 2 + 2 = **24**
- headroom: 200 − ~36 (other beams) − ~10 (psql/overhead) ≈ 154 usable
  → 154 / 24 ≈ **6-7 concurrent xaas lanes** (was ~4)
- ExUnit `max_cases` = schedulers × 2 = 32 > pool 10 by design; checkout
  queueing is absorbed by the existing `queue_target: 5_000` /
  `queue_interval: 10_000` on Xaas.Repo (guarded by
  `test/xaas/repo_test_pool_config_test.exs`, which asserts only the queue
  settings, not pool_size — verified before editing).
- Oban `testing: :manual` opens no queue connections in tests.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/chicago
  → 150 passed, 0 failures, 0 skipped (2.6s)
```

Post-change census: server total **108/200** connections; `psql` connects
normally again. Post-change per-lane footprint confirmed lower (xaas lanes
previously ~41 conns; server no longer saturated while multiple beams run).

## Standing

ALIVE (test-env scope). Residual risk: >7 concurrent xaas lanes can still
overshoot; the headroom-math comment in config/test.exs documents the lane
budget. Coordinator note for future waves: pool sizing in config/test.exs is
shared state across lanes — change both pools together.
