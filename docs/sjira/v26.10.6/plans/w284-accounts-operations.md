# W284 Integration Receipt — accounts + operations combined gate

- **Subject**: `/Users/sac/xaas` @ `d1db2b03179975213c14663b9dbd86b5ac2a14cf` (branch `feat/playwright-surface`), working tree as-found (post W183 revocation courts + W42 gymact adapter + W23 ingest policies, post-format).
- **Gate command**:

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/accounts test/xaas/operations 2>&1 | tail -5
```

- **Real output (tail)**:

```
Finished in 9.9 seconds (0.8s async, 9.1s sync)

Result: 72 passed, 5 excluded
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
[os_mon] memory supervisor port (memsup): Erlang has closed
```

- **Standing**: ALIVE — all green (72 passed, 0 failures, 0 errors), 5 excluded (tagged, pre-existing).
- **Scope**: combined integration lane W284, v26.10.6 convergence — W183's revocation courts, W42's gymact adapter, W23's ingest policies verified together on one subject.
- **Consequence**: the three lanes' surfaces coexist and pass jointly on exact head `d1db2b03`; no fixes applied, no git actions taken.
- **Replay**: rerun the gate command above at this SHA; expected `Result: 72 passed, 5 excluded`.
- **Falsifiers (open)**: full `mix test` suite and mock gate (`mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'`) not run on this lane — out of scope per dispatch.
