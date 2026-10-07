# W146 — Chicago Suite Receipt (post-wave, v26.10.6)

Date: 2026-10-06. Repo: /Users/sac/xaas. Branch: feat/playwright-surface (canonical checkout, no worktree).

## Command (the gate)

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/chicago 2>&1 | tail -12
```

## Result: BUILD_BROKEN — zero tests executed

`mix test test/xaas/chicago` (and plain `MIX_ENV=test mix compile`, exit 1) dies at the
compile/verify stage, before ExUnit starts:

```
==> ash_surface
Compiling 5 files (.ex)
    warning: redefining module AshA2A.Dsl (current version loaded from
      /Users/sac/xaas/_build/test/lib/ash_a2a/ebin/Elixir.AshA2A.Dsl.beam)
    ...
** (EXIT from #PID<0.94.0>) an exception was raised:
    ** (UndefinedFunctionError) function AshA2A.Dsl.dsl_patches/0 is undefined or private
        (ash_a2a 26.10.4) AshA2A.Dsl.dsl_patches()
        (spark 2.7.6) lib/spark/dsl/extension.ex:2276: Spark.Dsl.Extension.__after_verify__/1
```

- Counts verbatim: no `N tests, 0 failures` line exists — the runner never started.
  Tests run: **0**. Passed: **0**. Failed: **0**. Compile exit code: **1**.
- Root cause: path dep `../ash_surface` (mix.exs:115) redefines the module name
  `AshA2A.Dsl` (deps/ash_surface/lib/ash_a2a/resource.ex:71) that the real hex/git
  `ash_a2a 26.10.4` already defines; spark 2.7.6's `Spark.Dsl.Extension.__after_verify__/1`
  then requires `AshA2A.Dsl.dsl_patches/0`, which the shadowing definition lacks.
  This is the ash_surface namespace-plumbing surface that EA35 / commit d1db2b03
  ("fix(ash-surface): unblock full-app generation") is mid-flight on — pre-existing,
  not session-introduced, not a chicago-suite defect.
- Lane constraints (no lib edits, no git) forbid touching `../ash_surface` or mix.exs.

## Stale-vocabulary check (the W117 concern)

Inspected `test/xaas/chicago/**` for stale `candidate`-only standing assertions.
**None found.** Every `candidate` occurrence in the chicago test tree is the
unrelated `candidateOnly` prediction-case vocabulary of the negative courts
(`test/xaas/chicago/negative_courts/chicago_graph_courts_test.exs`,
`negative_courts/support/mutants.ex`, `seller/seller_live_test.exs`
`candidateLayers` delivery-state field, fixtures) — a different concept from the
W117 successor-standing change. `lib/xaas/chicago/layer.ex` defines
`successor_ids/0` (`~w(wasm4pm castle)a`) and `known?/1` already includes
successors; no ExUnit assertion promotes `candidate` to a standing value where
`successor` is the typed standing. **No test edits made; no lib edits; no git.**

## Standing

- Chicago suite: **BLOCKED(BUILD_BROKEN)** — blocker is the ash_surface
  `AshA2A.Dsl` module-shadowing + `dsl_patches/0` Spark-verify failure owned by the
  ash_surface/EA35 lane. Once that path dep compiles clean under MIX_ENV=test,
  rerun this exact gate and append real counts.
- Falsifier to clear the block: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile`
  exits 0.

## W154 rerun

Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/chicago`

Verbatim output (tail):

```
Finished in 2.0 seconds (1.2s async, 0.7s sync)

Result: 150 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

Counts: 150 passed, 0 failures, 0 errors, 0 skipped.

Failure classification: none. The W146 BLOCKED(BUILD_BROKEN) ash_a2a module
collision is resolved by W126's fixtureOnly pack fix + quarantine; suite is now
ALIVE. (os_mon shutdown lines are normal VM teardown noise, not failures.
One pre-existing warning: `parked.receipt_ref != nil` comparison in
test/xaas/chicago/bridges/pplan_test.exs:77 — literal-vs-literal, test passes.)

## W254 post-format

2026-10-06, integration lane W254, repo /Users/sac/xaas (branch feat/playwright-surface).
Context: seller_live.ex was formatted in W237's sweep; W154's 150/0 predates that format.
Command: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/chicago 2>&1 | tail -4`

First two runs aborted in test-DB migration setup before any test executed:
`** (Postgrex.Error) ERROR 42701 (duplicate_column) column "spg_graph_id" of relation "actuation_intents" already exists`
— caused by concurrent-lane in-flight migration `priv/repo/migrations/20261006212508_add_w247_convergence_snapshots.exs` (untracked) adding `spg_graph_id` to `actuation_intents`/`actuation_receipts`, duplicating `20260925061500_add_spg_identity_to_actuation_evidence.exs`. Clearned once the other lane's state settled; no changes made on this lane (no fixes, no git).

Actual output of the passing run:

```
................................................................................
Finished in 2.0 seconds (1.3s async, 0.7s sync)

Result: 150 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

Target met: 150 passed, 0 failures. Post-format chicago receipt confirmed.

## W277 final

2026-10-06, integration lane W277, v26.10.6 convergence, repo /Users/sac/xaas (branch feat/playwright-surface).
Context: final chicago receipt post-everything — format sweep, all lane fixes, and W187's assertion alignments included.
Command: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/chicago 2>&1 | tail -4`

Actual output:

```
Result: 150 passed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
[os_mon] memory supervisor port (memsup): Erlang has closed
```

Target met: 150 passed, 0 failures, first run clean (no migration contention this lane). Chicago suite confirmed green post-everything.

## W294 surface+bridges post-format

Post-format surface/bridges slice (both formatted in W237; W254's 150/0 predates it).

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/chicago/surface test/xaas/chicago/bridges 2>&1 | tail -4
```

Real output (2026-10-06 14:48):

```
Result: 47 passed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
[os_mon] memory supervisor port (memsup): Erlang has closed
```

Target green: 47 passed, 0 failures, 0 skipped. Grafana/PromEx dashboard-upload nxdomain warnings are environmental (no local Grafana), not test failures.
