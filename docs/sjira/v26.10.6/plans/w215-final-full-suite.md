# W215 — Final Full-Suite Measurement Receipt (v26.10.6, DoD criterion 1)

- Repo: /Users/sac/xaas, branch feat/playwright-surface
- Measurement window: 2026-10-06, ~14:08–14:41 local (two runs)
- Full run-2 log preserved at /tmp/w215-full-suite.log

## Commands (executed as given)

- Run 1: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token MIX_ENV=test mix test 2>&1 | tail -25`
- Run 2 (identical, full log captured): `... mix test 2>&1 | tee /tmp/w215-full-suite.log | tail -8`
- Mock gate (run twice): `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix run --no-compile -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'`

## Verbatim results

Run 1 (tail -25 only; full failure detail not captured):
```
Result: 3144/3230 passed (6/6 doctests, 3138/3224 tests), 36 skipped, 91 excluded
Failed: 86 tests
```

Run 2:
```
Result: 2811/3231 passed (6/6 doctests, 2805/3225 tests), 36 skipped, 91 excluded
Failed: 420 tests
```

Mock gate: `[]` both times. **Mock gate PASS.**

## Run 2 failure classification (420 failures)

Error-class census over /tmp/w215-full-suite.log:

| error class | count |
|---|---|
| `System.EnvError ... "INTERNAL_API_TOKEN" ... not set` | 138 |
| `Ash.Error.Unknown` | 129 |
| `MatchError` (no match of right hand side) | 95 |
| `Postgrex 42809 wrong_object_type: op ANY/ALL (array) requires array on right side` | 17 |
| `Postgrex FATAL 57P01 admin_shutdown` (xaas_test DB killed mid-run at 14:30:34) | 9+ connections |
| `AshR2RML.Resource.Info.mapping/1 is undefined` | 2 |
| `expected response with status 401, got: 503` | 2 |
| `DBConnection.ConnectionError` pool queue drops (19.9s / 22.9s) | 2 |

Top failing modules: RankerTest 17, LeaseVerifierTest 12, NextReadTest 12, HoldRequestTest 12, SubscriptionTest 11, LeaseSurfaceTest 10, plus a ~40-file long tail of controller tests failing on the INTERNAL_API_TOKEN EnvError.

## Classification verdict: tree NOT converged during measurement — results do not qualify DoD criterion 1

Known-typed-set mapping:

1. **W171-in-flight files (dominant class).** The checkout was actively mutated by other
   lanes during both measurement runs: 39 files with mtime 14:18:28; further mutations at
   14:25:09, 14:25:45, 14:28:13, 14:29:28, 14:34:26, 14:39:24, 14:41:28, 14:41:42; and live
   compilation of lib files during a measurement (run-2 log contains `Compiling
   lib/mix/tasks/xaas.autonomy.qualify.ex (it's taking more than 10s)`). Run-to-run delta
   (86 → 420 failures on an unchanged command) is itself direct evidence of a moving tree.
2. **Witness env.** `Xaas.Witness.CatalogTest` list_by_algorithm failure returns multiple
   rows where one is expected — consistent with shared-`xaas_test`-DB contamination from a
   concurrent lane's suite, not a catalog defect on a quiet tree.
3. **OS-9 court machinery typed-skips.** Skips held at exactly 36 in both runs (plus 91
   excluded); skip set stable, no regression in the typed-skip corpus observed.
4. **Shared-DB/infra contention.** `admin_shutdown` at 14:30:34 (someone recreated/restarted
   the xaas_test database mid-run), Postgres `too_many_connections`, and pool-queue drops —
   all from concurrent lane activity against the same Postgres and `_build`.

Residual un-attributed-to-contamination items, flagged NOT fixed per mandate (no-fix lane):
- 17 x `wrong_object_type: op ANY/ALL (array)` concentrated in
  test/xaas/receipt/r_projection_test.exs (8), ultracode semantic wave/trigger/provenance/work
  tests (9) — needs a quiet-tree rerun to attribute.
- 2 x `AshR2RML.Resource.Info.mapping/1 undefined` — possible real missing module on a
  quiet tree.

Note on the INTERNAL_API_TOKEN EnvErrors: current on-disk test/test_helper.exs line 13
unconditionally sets `System.put_env("INTERNAL_API_TOKEN", "test-only-internal-api-token")`,
and the variable is verifiably present in the VM env (mix run check returned
`{:ok, "dev-e2e-token"}`). 138 EnvErrors under that condition is only explicable by
in-flight edits to test/plug code during the run (the checkout was being mutated
throughout; current test_helper.exs sets the token unconditionally) — in-flight
class, not a token-supply problem. Exact attribution needs a quiet-tree rerun.

## Status

- Mock gate: PASS (`[]`).
- Full suite: NOT MEASURED VALIDLY — both runs ran on a mutating tree with a shared,
  concurrently-restarted test database. Counts above are real but do not qualify DoD
  criterion 1. A re-measurement is required once the checkout is quiescent (no other lane
  writing/compiling, exclusive xaas_test access) and should be re-run from this receipt.
