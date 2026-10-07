# W456 — Final-Tree Bridges Slice Receipt

- Repo: /Users/sac/xaas @ feat/playwright-surface (canonical checkout, no commits)
- Scope: lib/xaas/bridges/ (incl. pplan) vs test/xaas/bridges + test/xaas/chicago/bridges

## Command

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW456 \
  mix test test/xaas/bridges test/xaas/chicago/bridges
```

## Real tail

```
Finished in 1.8 seconds (0.2s async, 1.6s sync)

Result: 38 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```
Exit code 0.

## Verdict

**bridges slice green-at-final-tree** — 38 passed, 0 failed, 0 skipped,
exit 0. No failures; no AshPPlan.Continuation compile-class error observed
(W392's lib-compile claim remains unconfirmed by test side too — nothing
surfaced here).

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW456` was DENIED by the permission
system (2026-10-06). The `_build-laneW456` lease directory remains on disk
in /Users/sac/xaas — coordinator must delete it at integration per the
lane-cleanup law.
