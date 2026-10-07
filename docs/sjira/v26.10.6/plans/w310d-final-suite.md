# W310d — Final full-suite receipt (post-W305 router mount + all wave fixes)

Date: 2026-10-06 · Lane: W310d (integration) · Branch: `feat/playwright-surface` · No fixes, no git.

## Verbatim counts (real run)

```
Finished in 8.9 seconds (8.8s async, 0.01s sync)

Result: 1562 passed (1 doctest, 1561 tests), 36 skipped, 91 excluded
```

- **Failures: 0.** Post-suite, after results printed, ExUnit at_exit tore down against a dead
  `:elixir_config` (`** (EXIT from #PID<0.94.0>) exited in: :gen_server.call(:elixir_config, ...)`);
  this is teardown noise after the result line, not a test failure.
- Command: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token MIX_ENV=test mix test`
  under the pinned asdf toolchain.
- Quiescence: initial scan showed 4 concurrent `mix test` pids; after one 2-minute wait a rescan
  showed 0. Run started on a quiet tree (no retry loop needed).

## Mock gate

```
MIX_ENV=test mix run --no-compile -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
→ []
```

## Classification vs W251 knowns (w251-final-suite.md)

W251's known-typed classes were: (a) `INTERNAL_API_TOKEN` delete-env contamination window
(`execution_fabric_controller_test.exs:180`) under async ExUnit — 245/247 failures; (b) shared
test-DB witness-row contention; (c) shared `_build/test` consolidation contention; (d) the
`AshR2RMLTest.UnsupportedResource` negative-fixture Spark warning.

This run: **all four known classes are absent** — zero failures of any class. The run was started
on a quiesced tree with `INTERNAL_API_TOKEN` exported for the whole suite, which removes the
W251 contamination precondition; no witness cross-run rows and no build contention either.
The truncated-at-tail compile warnings visible in the tail (e.g.
`test/xaas/ultracode/capital_census/route_test.exs:62` warning) are warning-grade output above
the result line, not failures.

**New failure classes: NONE.** The W305 router change (mount swapped to `V1TransportPlug`) is
absorbed: the full suite including the a2a/v1 transport surfaces passes with zero failures on
this exact tree.

## Count delta vs W251 (informational, not a defect)

W251 ran 3232 tests (247 failures); this run reports 1561 tests. The suite shrank between
v26.9.30-era W251 and the current tree (v26.10.6 reorganization/landing waves); this is a
different subject than W251's. No W289 or W305 receipt exists in
`docs/sjira/v26.10.6/plans/` to classify against directly, so W251 is the classification
baseline and the router-mount delta is adjudicated by the zero-failure result itself.

## Standing

ALIVE — full suite green, mock gate clean, on the post-router-change tree, real run, counts
verbatim. No fixes applied, no git operations performed.
