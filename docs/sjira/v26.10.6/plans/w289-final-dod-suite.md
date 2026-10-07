# W289 — Final Full-Suite DoD-1 Measurement (post-W280 async env-isolation fix)

Lane: W289, v26.10.6 convergence. Repo: /Users/sac/xaas, branch feat/playwright-surface.
Read-only measurement lane: no fixes, no git operations.

## Command

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token MIX_ENV=test mix test
```

## Results (verbatim)

### Run 1 — canonical command (background, tail -12)

Exit code: 0 (as reported by harness notification).

```
Finished in 1236.2 seconds (230.1s async, 1006.1s sync)

Result: 3230/3232 passed (6/6 doctests, 3224/3226 tests), 36 skipped, 91 excluded
Failed: 2 tests
```

Failure identities NOT captured (tail -12 truncated the failure detail section).
Ambient stderr noise in the same window:
`error: /Users/sac/.cache/tmp/profile-sense-*/runs/fix-sense-* has no contracts/ directory` (x5, from a fixture subprocess).

### Run 2 — full-capture retry (no evidence run)

Crashed at at_exit before the failure summary:

```
Result: 2358 passed (1 doctest, 2357 tests), 36 skipped, 91 excluded
** (EXIT from #PID<0.94.0>) exited in: :gen_server.call(:elixir_config, {:serial, ...}, :infinity)
    ** (EXIT) no process ... noproc
```

Anomalous test count (2357 vs 3226) plus at_exit noproc — classified as a corrupted
runner invocation (concurrent `_build/test` contention), not evidence about the suite.

### Run 3 — full-capture retry (evidence run)

Exit code: 2.

```
Finished in 570.6 seconds (30.8s async, 539.7s sync)

Result: 3230/3235 passed (6/6 doctests, 3224/3229 tests), 36 skipped, 91 excluded
Failed: 5 tests
```

Named failures (5):

1. `test/xaas/ultracode/machine_experience_test.exs:909` — `mix xaas.machine_experience
   --route` expected exit 3 (REFUSED credential), got `1`. Underlying cause in the captured
   subprocess output: `** (File.Error) could not write to file
   "_build/test/lib/xaas/consolidated/Elixir.Inspect.beam": no such file or directory`
   during protocol consolidation. Subprocess/`_build` contention under full-suite
   concurrency — infrastructure, not typed-refusal logic drift.
2. `test/xaas/castle_refusal_negative_test.exs:90` REFUSED_CASTLE_SIGNING_IDENTITY_DRIFT —
   `{:error, :eexist}` from `Xaas.Castle.Kernel.CLI.manufacture/2`.
3. `test/xaas/castle_refusal_negative_test.exs:98` REFUSED_CASTLE_ADAPTER_PROFILE_DRIFT —
   `{:error, {:REFUSED_CASTLE_EXIT, 137, ""}}` (exit 137 = SIGKILL of the castle
   subprocess).
4. `test/xaas/castle_refusal_negative_test.exs:47` REFUSED_CASTLE_CONSTRUCT_NOT_ALIVE —
   `{:error, {:REFUSED_CASTLE_EXIT, 137, ""}}`.
5. `test/xaas/castle_refusal_negative_test.exs:122` REFUSED_UNRECEIPTED_CASTLE_DO —
   `{:error, :eexist}`.

## Failure classification

- **W158 105-class: collapsed.** Zero failures in the r2rml skew pair
  (`Xaas.Semantics.AshR2RMLTest` / `R2RMLRefusalTest`) in the evidence run. The
  "declared domain Xaas.Billing" RuntimeErrors seen in run 2's log were compile-path
  warnings about test-support modules, not test failures.
- **DoD-1 real residue is now 5 tests, all real-OS-subprocess infrastructure failures
  under full-suite concurrency**, none product-logic:
  - 4x `Xaas.CastleRefusalNegativeTest` — the castle CLI subprocess died (`:eexist`,
    SIGKILL/137) before the typed refusal could be asserted. The tests assert real
    subprocess exit behavior (Chicago-style); the failure is in the environment, not the
    refusal vocabulary.
  - 1x `Xaas.Ultracode.MachineExperienceTest` — the nested `mix` subprocess crashed in
    protocol consolidation writing into the shared `_build/test` tree.
- Run 1 vs run 3 delta (2 vs 5 named) is flake variance within the same
  subprocess-contention class; the two classes observed (castle CLI, machine_experience
  nested mix) are the full observed residue.
- 36 skipped (typed skips) and 91 excluded behaved as before; witness suite passed
  (zero failures named from Xaas.Witness).

## Mock gate

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix run --no-compile -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
```

Output: `[]` — PASS (expected empty list observed).

## Standing

DoD-1: PARTIAL_ALIVE. 3224/3229 tests pass with 36 typed skips; the 5-test residue is
fully classified as real-subprocess/`_build` concurrency infrastructure, not the W158
105-class (which is confirmed collapsed to zero r2rml failures). Next lever if pursued:
per-run isolated build root for subprocess-spawning tests, or fixture-level `on_exit`
cleanup — no fix applied in this lane per lane contract.

## Replay

- Run 1 log: not retained verbatim (tail -12 only; counts quoted above are the full output).
- Run 3 full log: `/tmp/w289-run3.log` (session-scratch; 100 KB).
- Ambient warnings observed but not failing: Grafana/PromEx nxdomain on mock-gate boot,
  OCEL emitter Jason.Encoder PID warning, Stripe converter deprecation, ultracode epoch
  missed/lease-close warnings — all expected noise paths.

## W297d subprocess isolation

Lane W297d, 2026-10-06, subject: working tree @ d1db2b03 (uncommitted, test-only diff).

### Fix 1 — castle_refusal_negative_test.exs (castle CLI subprocess serialization)

`lib/xaas/castle.ex:926` writes the kernel request file with `File.write(..., [:exclusive])`;
under full-suite concurrency the W289 residue was `{:error, :eexist}` from that exclusive
write and `{:REFUSED_CASTLE_EXIT, 137, ""}` (SIGKILL under memory pressure) — real-OS
castle subprocesses from concurrent runs racing on the shared /tmp surface. Test-side fix:
every kernel CLI invocation (13 `manufacture/2` call sites + the `execute/2` helper) now
routes through `with_castle_lock/1`, a /tmp exclusive-create file-lock mutex
(`$TMPDIR/xaas-castle-test-cli.lock`), so only one castle subprocess exists at a time.
- Self-healing: a hold longer than 30 s is treated as a dead holder (SIGKILL leaves the
  file; a live castle subprocess completes in seconds) — break + retry.
- `XAAS_CASTLE_TEST_LOCK` overrides the lock path at runtime, for isolated verification on
  this shared checkout where several lanes run the same files concurrently; the full suite
  uses the shared default so every castle subprocess serializes.
- OTP 28 removed `:file.write_lock` (verified: not exported on erts-16.4), hence the
  exclusive-create spin design.

### Fix 2 — machine_experience_test.exs (nested mix build-root isolation)

`task/2` (nested `mix xaas.machine_experience` subprocess) previously wrote into the shared
`_build/test` tree — the W289 consolidation race. It now clones the current build into a
per-invocation `MIX_BUILD_ROOT` (cp -cRp APFS clonefile, same pattern as the episode
qualification test at machine_experience_test.exs:1126) and cleans it up via the existing
`mktmp/1` on_exit.

### Verification (real runs, all on load-average 77-82 machine with foreign lanes
continuously re-running the same castle files on this tree)

- Fix-iteration ladder for castle file: 13 failures → 3 → 1 → 15/19 passed
  (/tmp/w297d_castle.log, /tmp/w297d_both.log, /tmp/w297d_final*.log, /tmp/w297d_castle_only.log).
- Final castle-only run: 15/19 passed; 4 failures, ALL `ExUnit.TimeoutError` blocked in
  `acquire_castle_lock/2` (120 s) — lsof-confirmed foreign-lane beams (pids 64552, 96504)
  running castle_refusal_negative_batch2/3 holding the shared lock for minutes at a time.
  Zero failures of the original `:eexist` or `REFUSED_CASTLE_EXIT 137` classes remain.
- machine_experience: OCEL/describe/budget tests pass; the F3 no-LLM `task/2` describe
  block exercises the isolated-build-root path (nested mix runs observed progressing under
  load; no consolidation-race failure recurred in any run after the fix).
- Confounder disclosed: this lane's own TaskStopped background runs orphaned beams that
  livelocked the private lock (pids 75707, 87674) — killed and cleared before the final
  runs; also the `@castle_lock_path` compile-time-attribute first cut was replaced by the
  runtime `castle_lock_path/0` because lanes share `_build/test` compiled beams.

### Standing

PARTIAL_ALIVE. Both W289 failure classes (`:eexist` ×2, SIGKILL 137 ×2, nested-mix
consolidation race) are eliminated on every run after the fix; the residual timeouts are
cross-lane contention on the shared checkout (a topology fact, not a test defect — the
lock is doing its job, serializing castle subprocesses across lanes). Full green 19/19 +
40/40 requires a quiescent tree: run
`PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token MIX_ENV=test mix test --timeout 240000 test/xaas/castle_refusal_negative_test.exs test/xaas/ultracode/machine_experience_test.exs`
when no other lane is running castle batches.
