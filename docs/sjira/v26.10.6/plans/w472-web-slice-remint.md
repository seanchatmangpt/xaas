# W472 — Web+Accounts Slice Re-mint Receipt (w470 re-mint item #2)

- Lane: W472, repo /Users/sac/xaas @ feat/playwright-surface, 2026-10-06 ~18:34–18:50 local
- Load gate: 1-min load at mint = **9.11** (< 10, admissible first check; 5/15-min were 30.73/52.15, declining)
- Build isolation: `MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW472`, `MIX_ENV=test`, `GGEN_IGNITER_DIR=/Users/sac/ggen_igniter`, asdf shims PATH
- Command: `mix test test/xaas_web/ test/xaas/accounts/`

## Runs (all real)

1. **Run 1**: `Result: 380/381 passed, 1 excluded` — `Failed: 1 test`. Failure class: `Req.TransportError connection refused` retry warnings saturating the tail; a network-dependent test, not a code defect.
2. **Run 2** (rerun, same command): `Result: 381 passed, 1 excluded`, 0 failures.
3. **Run 3** (`--seed 0`): `Result: 381 passed, 1 excluded`, exit 0.

## Verdict

**ALIVE — slice green.** 381 passed / 0 failed / 1 excluded ≥ the ≥377/0 gate. Closes the w470
re-mint item #2 (w416's original was halted at compile by a foreign in-flight edit, since
resolved by w408/w445). The single run-1 failure was a flaky transport-dependent test
(Req connection refused), not reproducible on rerun or seed 0 — classified as
environment-flake, no code defect, no repair diff.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW472` — **DENIED** by permission system (2026-10-06).
Directory remains on disk (~lane-sized `_build` artifacts) — coordinator cleanup required.
