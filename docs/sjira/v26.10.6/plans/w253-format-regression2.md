# W253 — Format Regression Coverage (remaining 5 files)

Wave: v26.10.6 convergence, integration lane W253. Context: W237 formatted 39 files;
W244 verified 6 test files. This lane covers the rest.

## Task

Run the 5 remaining test files most likely to be touched by the format sweep;
target: all green, format-only changes must not alter behavior.

## Command

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
  test/xaas/ultracode/sj_program_registry_test.exs \
  test/xaas/ultracode/autonomic_profile_sense_test.exs \
  test/xaas/telemetry/ocel_ash_emitter_test.exs \
  test/xaas/sa2a/route_test.exs \
  test/xaas/sjira/ard_court_test.exs
```

## Result (real output, 2026-10-06)

```
Finished in 8.7 seconds (3.3s async, 5.3s sync)

Result: 149 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

Exit: 0. 149 passed, 0 failed, 0 skipped, 0 invalid.

## Standing

ALIVE — all 5 files green under the pinned toolchain. No fixes made, no git actions.
The os_mon shutdown lines are normal teardown noise, not failures.

Coverage state: W237 (39 files formatted) + W244 (6 files) + W253 (5 files) —
no behavioral regressions observed in any covered file.
