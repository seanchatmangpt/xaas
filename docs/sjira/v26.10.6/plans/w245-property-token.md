# W245 — property suite re-run WITH INTERNAL_API_TOKEN

Lane: W245, integration, v26.10.6 convergence. Repo: /Users/sac/xaas (canonical checkout, branch feat/playwright-surface).
Purpose: W104's property class was 104-failed dominated by INTERNAL_API_TOKEN EnvError; re-run WITH token to isolate real failures.

## Command

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token MIX_ENV=test mix test --include property
```

## Run 1 (first attempt, output truncated to tail -15)

```
Failed: 231 tests
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
[exited with code 0]
```

No failure detail captured (tail truncation). 231 failures is not reproducible (see run 2).

## Run 2 (full log, /tmp/w245_property_full.log)

```
Finished in 580.7 seconds (53.0s async, 527.7s sync)

Result: 2641/2644 passed (1/1 doctest, 2640/2643 tests), 36 skipped, 90 excluded
Failed: 3 tests
```

(Note: log's last lines also contain an `:elixir_config` noproc at_exit crash — teardown noise
after the summary printed, likely from the background-task SIGKILL at the harness time limit;
the summary above is complete and printed before it.)

### The 3 failures

1. `Xaas.Witness.CatalogTest` — test list_by_algorithm lists ingested receipts by admitted
   algorithm — test/xaas/witness/catalog_test.exs:123 — `assert [%CertifiedReceipt{} = r] = ...`
   returns 3+ rows: rows inserted at 21:32:52Z (run-2 window) persist into later runs.
2. `Xaas.Ultracode.MachineExperienceTest` — real OS process sub-mix run:
   `Waiting for lock on the build directory (held by process 79795)` (x3), then
   `no_llm_env.sh: line 146: 80812 Killed: 9` — expected `{refused, 3}`, got exit 137.
3. `Xaas.Sjira.V26923GoalTest` — courts/gi_mix.sh — File.write! failure during protocol
   consolidation into the private build copy, then
   `UNKNOWN: gi_mix: no graph-side toolchain resolves for /Users/sac/.cache/tmp/v23_gi_mix_probe_46595`.

## Isolation re-run (3 files, same env)

```bash
mix test test/xaas/witness/catalog_test.exs test/xaas/ultracode/machine_experience_test.exs test/sjira/v26_9_23_goal_test.exs --include property
```

```
Finished in 278.3 seconds (222.9s async, 55.3s sync)

Result: 59/60 passed, 8 skipped
Failed: 1 test
```

- `Xaas.Ultracode.MachineExperienceTest` — PASSES in isolation → shared-build contention
  (explicit build-lock wait + SIGKILL of the sub-mix in the full run).
- `Xaas.Sjira.V26923GoalTest` — PASSES in isolation → shared-build contention.
- `Xaas.Witness.CatalogTest` — STILL FAILS in isolation, same assertion, same extra rows.
  Rows persist across test invocations (inserted_at from the previous run's window survive
  into the isolation run) → real failure: `witness_certified_receipts` rows are not cleaned
  up / not sandbox-isolated for this test.

## Classification

| Failure | Class |
|---|---|
| Xaas.Ultracode.MachineExperienceTest | shared-build contention (concurrent `_build/test` lock; sub-mix killed) |
| Xaas.Sjira.V26923GoalTest | shared-build contention (private build copy derivation failed under contention) |
| Xaas.Witness.CatalogTest | REAL — cross-run data leakage in witness_certified_receipts; `list_by_algorithm/1` returns rows from prior runs, breaking the single-row assertion at test/xaas/witness/catalog_test.exs:123 |

## Headline

With the token set, the property class goes from 104-failed/231-failed noise to
2641/2644 passed with exactly 1 real failure (Witness.CatalogTest data leakage) and 2
contention artifacts. Note: run 1 (same command, 231 failed) vs run 2 (3 failed) on the
same tree also indicates heavy run-to-run contention variance in the full suite; treat
single-digit failures in full-suite runs as suspect and re-run in isolation before classifying.

No fixes made, no git operations. Logs: /tmp/w245_property_full.log, /tmp/w245_isolation.log.

## W297c catalog isolation

**Subject**: /Users/sac/xaas @ feat/playwright-surface, only file touched:
test/xaas/witness/catalog_test.exs.

**Diagnosis**: the catalog test already checked out the Ecto sandbox
(`Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)`), so its own writes roll back,
but the sandbox does not hide rows persisted by prior runs (e2e-w55 seeds and
earlier non-wrapped writes to witness_certified_receipts). `Catalog.list_by_algorithm(:es256)`
at test/xaas/witness/catalog_test.exs:123 then matched `[r]` against stale
rows and failed. Same class as W257's LiveView leak.

**Fix**: extend the setup block, same pattern as W257 — inside the checked-out
sandbox, `Xaas.Repo.delete_all(CertifiedReceipt)` and
`Xaas.Repo.delete_all(VerificationKey)` before each test.

**Verification (real output)**:
- `MIX_ENV=test mix test test/xaas/witness/catalog_test.exs` → `Result: 6 passed`
- `MIX_ENV=test mix test test/xaas/witness/catalog_test.exs test/xaas_web/live/witness_live_test.exs`
  → `Result: 9 passed` (6 catalog + 3 liveview, both green both orders)

No lib changes, no git actions.
