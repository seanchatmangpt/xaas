# W300 — THE definitive final full-suite receipt (post-everything)

- Lane: W300 integration, v26.10.6 convergence, repo /Users/sac/xaas (canonical checkout).
- Subject: branch `feat/playwright-surface` @ `d1db2b03` (working tree, uncommitted
  convergence edits present per coordinator fan-out state — no git transitions taken).
- Post-state witnessed: W280 async isolation, W247/W258 migration, W229 autonomic fix,
  W249 atom fix, format sweep.
- Receipt date: 2026-10-06T22:41Z. No fixes, no git actions taken by this lane.

## 1. Quiescence (precondition, observed)

Confirmed lane processes drained before start:

- Initial state (15:02Z): 14+ beam.smp `mix` processes on this checkout (two full-suite
  `mix test` runs, W245/W248/W251/W262 lane runs, ggen_igniter.sync, PW e2e `--no-halt`
  servers). Waited per same-checkout fan-out law (poll, lsof-cwd verified).
- One lingering `mix run --no-halt` (PW e2e server, PID 11178) drained at ~15:29Z.
- At launch: 0 mix processes with cwd under /Users/sac/xaas. (Note: two new lane beams
  appeared during the run — contention disclosed, run still completed.)

## 2. Transport failure (first attempt, disclosed)

First launch (15:25:33Z) died at boot: `SIGTERM received` → `GenServer.call(Mix.ProjectStack
...) noproc`. Classified: external SIGTERM to the process (concurrent fleet activity), not a
code/build failure. Second launch (nohup-detached) ran to completion. The noop `setsid`
attempt (command not found on macOS) left no state.

## 3. Command (exact)

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH \
  INTERNAL_API_TOKEN=dev-e2e-token MIX_ENV=test mix test 2>&1 | tail -12
```

(ran nohup-detached; full log preserved at /tmp/w300-final-suite.log)

## 4. Result (verbatim)

```
Running ExUnit with seed: 276407, max_cases: 32
Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel]
Finished in 563.5 seconds (22.9s async, 540.6s sync)

Result: 3235 passed (6 doctests, 3229 tests), 36 skipped, 91 excluded
```

Exit 0. Full log: `/tmp/w300-final-suite.log`.

## 5. Failure classification vs W289 baseline

**0 failures.** Nothing to classify.

- **The 105-class is GONE** — result line contains zero failures.
- **New classes: none.** Every "failure/Failed" string match in the log (6 total) is an
  expected negative-path `[Reactor.Audit] Failed with errors:` log emitted by PASSING
  refusal-path tests (actuation admit refusals: evidence-hash mismatch, unsupported
  "magic" causal identification, non-admitted certificate, `subject_id_required`,
  idempotency conflicts `test-provider-conflict-29700` / `two-port-139008450242`) —
  assertion-level outcomes all passed.
- 36 skipped / 91 excluded are tag-level (`:subprocess`, `:stress`, `:kind`, etc.),
  config-level exclusions, consistent with prior receipts (W283 saw the same exclusion set).

## 6. Mock gate (exact)

```bash
mix run --no-compile -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
```

Output (verbatim tail): `[]` — PASS. (Env noise: pre-existing PromEx/Grafana `:nxdomain`
dashboard-upload warning, unrelated.)

## 7. Standing

- Full suite on `feat/playwright-surface`@d1db2b03 working tree, post-W280/W247/W258/
  W229/W249/format-sweep: **ALIVE** — observed execution, exact command, exit 0,
  3235 passed / 0 failed.
- Mock gate: **ALIVE** (empty scan).
- Out of scope (tag-excluded, not witnessed here): `:subprocess` (incl. SJ-001 E2E),
  `:stress`, `:kind`, `:property`, external suites.
- v26.10.6 convergence: full-suite gate GREEN. Next lawful transition is the
  coordinator's (integration commit), not this lane's.
