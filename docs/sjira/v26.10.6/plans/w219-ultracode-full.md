# W219 — Full ultracode-dir test receipt (v26.10.6 convergence)

- **Lane**: W219 integration
- **Repo**: /Users/sac/xaas
- **Branch**: feat/playwright-surface
- **Subject (HEAD)**: `d1db2b03179975213c14663b9dbd86b5ac2a14cf`
- **Date**: 2026-10-06

## Command (exact)

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/ultracode 2>&1 | tail -10
```

## Result (verbatim)

```
Finished in 964.9 seconds (126.3s async, 838.6s sync)

Result: 1399 passed (6 doctests, 1393 tests), 11 skipped, 27 excluded
```

Exit code: 0

- Passed: 1399 (6 doctests + 1393 tests)
- Skipped: 11
- Excluded: 27
- **Failures: 0** — no re-runs needed; no flakes to classify.

## Anomaly observed (non-failing)

One captured error log during the run, from a test that PASSED:

```
14:11:41.720 request_id=GNwNDO3lPkeQG9Y4XZgB [error] [ultracode] verifier crashed: key :steps not found in: %{}
```

Logged by the ultracode verifier's crash-resilience path; the covering test exercises
the crash and asserts the fallback behavior. Counts unchanged, classification: expected
error-path log, not a test failure.

## Verification ladder

Narrow/full-directory ExUnit run over `test/xaas/ultracode` under the pinned asdf
toolchain, MIX_ENV=test. Full run, no tags, no filters.

## Standing

ALIVE — observed execution on subject `d1db2b03`, 0 failures.

## W274 post-W229

Command:

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/ultracode 2>&1 | tail -6
```

Real output:

```
........................................................................
Finished in 976.9 seconds (41.1s async, 935.7s sync)

Result: 1400 passed (6 doctests, 1394 tests), 11 skipped, 27 excluded
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

Exit code: 0

- Passed: 1400 (6 doctests + 1394 tests) — W219's 1399 baseline + W229's regression test
- Skipped: 11
- Excluded: 27
- **Failures: 0**

Verification ladder: full-directory ExUnit run over `test/xaas/ultracode` under the
pinned asdf toolchain, MIX_ENV=test. No tags, no filters.

Standing: ALIVE — observed execution on subject `d1db2b03`, 0 failures.

## W282 post-W229

Integration lane W282, v26.10.6 convergence. Full ultracode-dir receipt post-W229's
autonomic precedence fix, same command:

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/ultracode 2>&1 | tail -6
```

Real output (exit code 0):

```
Finished in 1017.5 seconds (49.2s async, 968.2s sync)

Result: 1275/1400 passed (6/6 doctests, 1269/1394 tests), 11 skipped, 27 excluded
Failed: 125 tests
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

- Passed: 1275/1400 (6/6 doctests, 1269/1394 tests)
- Skipped: 11
- Excluded: 27
- **Failures: 125** — regression vs. W219's 0-failure baseline; NOT investigated or
  fixed per lane scope (no fixes, no git). Working tree also carries the uncommitted
  branch-wide modifications visible at session start, so this subject differs from
  the d1db2b03 subject on which W219 recorded 0 failures.

Verification ladder: full-directory ExUnit run over `test/xaas/ultracode` under the
pinned asdf toolchain, MIX_ENV=test. No tags, no filters.

Standing: **BUILD_BROKEN** — observed execution on the working-tree subject at HEAD
`d1db2b03` plus uncommitted modifications; 125 failures, target ~1400/0 not met.
