# W120 — Web layer suite receipt (v26.10.6 convergence, integration lane)

- Date: 2026-10-06
- Subject: /Users/sac/xaas @ d1db2b03179975213c14663b9dbd86b5ac2a14cf (branch feat/playwright-surface)
- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web`

## Result (verbatim)

```
Finished in 24.5 seconds (3.0s async, 21.5s sync)

Result: 347 passed, 1 excluded
```

## Classification

- Failures: 0. Nothing to classify; no witness/next-read lane-active failures present.
- 1 excluded: pre-existing suite exclusion tag (not a failure).
- Non-fatal log noise during run: Postgres `too_many_connections` (53300) from
  Oban notifier / db_conn pool under concurrent test load; `Req.TransportError
  connection refused` retries in two request-scoped tests. All tests covering
  these paths passed; noise is environmental, not a court failure.

## Standing

- ALIVE for the web layer at this exact subject: 347/347 executable tests green.
- No fixes made, no git actions taken.

## W218 post-W150

Subject: /Users/sac/xaas @ feat/playwright-surface (working tree, v26.10.6 convergence), 2026-10-06.

Full web suite:

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web
...
Finished in 15.9 seconds (1.1s async, 14.8s sync)
Result: 350/351 passed, 1 excluded
Failed: 1 test
```

Run 2 (same command): 350/351 again, same shape — but note the failing test differs
per run depending on ordering/DB state.

Isolation rerun `mix test test/xaas_web/live/witness_live_test.exs`:
2/3 passed, 1 failed — **deterministic in isolation too** (reproduced 2/2 runs).

Failing test: `renders the typed empty state when no receipts exist`
(test/xaas_web/live/witness_live_test.exs:67) —
`assert has_element?(view, "[data-testid='witness-empty-row']")` got false.

Classification: **NOT the W150 witness TransportError flake and NOT a timing flake.**
It is test-database residue. The sandbox should isolate the LiveView, but
`witness_certified_receipts` in `xaas_test` contains rows written outside any
sandbox transaction:

```
psql -h localhost -U postgres -d xaas_test -c \
  "select subject, verified, inserted_at from witness_certified_receipts order by inserted_at desc limit 10;"
           subject          | verified |        inserted_at
---------------------------+----------+----------------------------
 sha256:e2e-w55-unverified | f        | 2026-10-06 20:39:39.242345
 sha256:e2e-w55-verified   | t        | 2026-10-06 20:39:39.174408
(2 rows)
```

These `e2e-w55-*` rows (from an earlier W55 e2e Playwright run that ingested
against xaas_test without rollback) make `@receipts == []` false at mount, so the
typed empty row never renders. The empty-state test has no pre-clean of the table,
so it fails whenever residue exists. Fix would be either deleting the residue rows
or a pre-clean in the test setup — out of scope for this lane (no-fixes mandate).

Standing: web suite at 350/351 with the single failure classified as
external-DB-residue (e2e-w55 rows), not a web-layer defect. No fixes, no git.

## W271 post-W171

Post-W171 web re-gate (ZoeEventSimulationAgent added to the supervision tree),
plus confirmation that the W257 witness empty-state fix holds.

Command (pinned toolchain, MIX_ENV=test):

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web 2>&1 | tail -5
```

Real output (2026-10-06T21:37:19Z, subject d1db2b03179975213c14663b9dbd86b5ac2a14cf):

```
Finished in 12.7 seconds (1.3s async, 11.3s sync)

Result: 351 passed, 1 excluded
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

Target 351/351 met: 351 passed, 0 failures, 1 excluded (pre-existing exclusion).
The W257 witness empty-state failure did not recur — the prior
external-DB-residue classification (e2e-w55-* rows in witness_certified_receipts)
no longer blocks the empty-state test on this run.

Standing: web suite ALIVE at 351 passed / 1 excluded on d1db2b03. No fixes, no git.

## W288 post-W280

Post-W280 web dir re-gate (env-isolation fix landed), full suite re-run.

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web 2>&1 | tail -4
```

Real output (2026-10-06T21:54:27Z, subject d1db2b03179975213c14663b9dbd86b5ac2a14cf):

```
Finished in 93.2 seconds (1.5s async, 91.6s sync)

Result: 351/352 passed, 1 excluded
Failed: 1 test
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

Target 351/351 NOT met: 351 passed, 1 FAILED, 1 excluded.

Deterministic failure (reproduced 3/3, including in isolation
`mix test test/xaas_web/a2a/v1_sse_test.exs:47` -> 0/1 passed):

```
1) test message/stream answers text/event-stream with a terminal
   TASK_STATE_COMPLETED frame (XaasWeb.A2A.V1SSETest)
   test/xaas_web/a2a/v1_sse_test.exs:47
   Expected truthy, got false
   code: assert get_resp_header(conn, "content-type") |> hd() |> String.starts_with?("text/event-stream")
   stacktrace:
     test/xaas_web/a2a/v1_sse_test.exs:55: (test)
```

Classification: the endpoint answers 200 (the `conn.status == 200`
assertion on the preceding line passes) but the response content-type
no longer starts with `text/event-stream`, i.e. message/stream on this
subject is answering with a non-SSE content-type. This test did not
appear in the previous W-entry run (351 passed, 0 failures at 21:37
per the prior section) — it is a change in observed behavior between
the two runs on the same subject d1db2b03, or was skipped/ordered
differently in the earlier run; either way it is deterministic on
isolation re-run, so not flake. No fix applied, no git actions, per
lane instructions.

Standing: web suite BLOCKED at 351 passed / 1 failed (V1SSETest
message/stream content-type) / 1 excluded on d1db2b03.

## W304 post-W270

Command (pinned toolchain, 2026-10-06):

    cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web 2>&1 | tail -4

Real output:

    Result: 351/352 passed, 1 excluded
    Failed: 1 test

Failure (verbatim from full log):

    1) test message/stream answers text/event-stream with a terminal TASK_STATE_COMPLETED frame (XaasWeb.A2A.V1SSETest)
       test/xaas_web/a2a/v1_sse_test.exs:47
       Expected truthy, got false
       code: assert get_resp_header(conn, "content-type") |> hd() |> String.starts_with?("text/event-stream")
       stacktrace:
         test/xaas_web/a2a/v1_sse_test.exs:55: (test)

Note: reproduced across 3 consecutive runs of the same suite invocation on
the same tree — deterministic, not flake. No fix applied, no git actions,
per lane instructions.

Standing: web suite BLOCKED at 351 passed / 1 failed (V1SSETest
message/stream content-type) / 1 excluded vs 352/352 target, on d1db2b03.
