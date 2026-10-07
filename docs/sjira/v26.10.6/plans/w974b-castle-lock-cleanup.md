# W974b — Castle Lock Cleanup Receipt

- **Lane**: W974b, campaign v26.10.6, repo `/Users/sac/xaas`
- **Date**: 2026-10-07
- **Branch**: feat/playwright-surface (no commit; receipt only)

## Scope

Delete only `/tmp/w974-castle.lock` (W974's stale isolated lock lease, lane finished
green 19/19 ×2). No other deletions, no build root.

## 1. Lock lease check

```
$ ls -la /tmp/w974-castle.lock
ls: /tmp/w974-castle.lock: No such file or directory

$ lsof /tmp/w974-castle.lock
lsof: status error on /private/tmp/w974-castle.lock: No such file or directory
```

**Outcome**: lock file already absent — nothing to delete, no deletion performed.
Per instruction, no other action taken on the lock.

## 2. Court verification (real runs, real tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/castle_refusal_negative_test.exs
Running ExUnit with seed: 578495, max_cases: 32
...................
Finished in 3.7 seconds (0.00s async, 3.7s sync)
Result: 19 passed
```

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/castle_execute_court_test.exs
Running ExUnit with seed: 912643, max_cases: 32
..........
Finished in 2.1 seconds (0.00s async, 2.1s sync)
Result: 10 passed
```

Both courts pass. (Ambient Grafana/PromEx nxdomain warnings are pre-existing
environment noise, unrelated to castle.)

## Standing

- **Lock cleanup**: N/A — lease already absent (stale lock self-expired or was
  cleared; no holder existed).
- **castle_refusal_negative court**: 19/19 ALIVE (observed execution 2026-10-07).
- **castle_execute court**: 10/10 ALIVE (observed execution 2026-10-07).

## Replay

```bash
ls -la /tmp/w974-castle.lock        # absent
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/castle_refusal_negative_test.exs   # 19 passed
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/castle_execute_court_test.exs      # 10 passed
```
