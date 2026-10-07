# W869 — Staleness Task Court (receipt)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` HEAD `a0723bf6`
- **Scope**: task-level court for the ex4pm ontology-staleness check
  (`lib/xaas/ontology/ex4pm_staleness.ex` + `lib/mix/tasks/xaas.telemetry.check_ontology_staleness.ex`,
  documented per W702). New file only: `test/xaas/ontology/staleness_task_court_test.exs`.
  No lib/config changes. Not committed (lane discipline).
- **Standing**: **ALIVE** (observed execution on the exact subject above).

## Court design (Chicago-style, zero mocks)

Every scenario runs the real `git` binary against real throwaway repos
(`git init/add/commit/rev-parse`) and varies the real config seam
`Application.put_env(:xaas, :ex4pm_ontology_check, ...)` that the module itself
reads. Vendored bytes are the REAL `priv/vendor/ex4pm/ocel.ex` read from the
tree (W702's byte-identical pin), staged into a temp repo at the pinned
upstream path `lib/ex4pm/ocel.ex`.

| # | Case | Asserted real verdict |
|---|---|---|
| a | fresh pin (real vendored bytes committed at pinned SHA) | `{:ok, :match}` |
| a2 | ambient machine config | never crashes; `:repo_absent` => graceful skip |
| b | corrupted temp vendored copy | `{:error, {:content_mismatch, up_hash, vend_hash}}`, 64-hex hashes, `vend_hash == real sha256(corrupted)` |
| c | `Mix.Task.run("xaas.telemetry.check_ontology_staleness")`, fresh fixture | captured stdout `OK: vendored ontology matches pinned upstream ex4pm content` |
| c2 | same task, corrupted fixture | raises `Mix.Error ~r/ontology staleness check failed/`, stderr carries `content diverges from pinned upstream ex4pm content` + `upstream sha256=` / `vendored sha256=` |
| c3 | absent sibling repo | captured `UNSUPPORTED (skipped)` + `not a failure` |
| d | determinism ×2 | fresh `{:ok, :match}` twice; mismatch hashes identical across two runs |

The complementary W702-era `test/xaas/ontology/ex4pm_staleness_test.exs`
remains `:external`-tagged; this court is default-runnable (no tags excluded).

## Real commands + output tails (this machine, this session)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW869 \
    mix test test/xaas/ontology/staleness_task_court_test.exs
Running ExUnit with seed: 900704, max_cases: 32
Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api,
  :external, :external_llm, :subprocess, :property, :castle_kernel, :eu_ai_act]
.......
Finished in 0.5 seconds (0.00s async, 0.5s sync)
Result: 7 passed
```
(exit 0; after removing 7 unused-`require ExUnit.CaptureIO` warnings, second
run is warning-clean)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW869 \
    mix xaas.telemetry.check_ontology_staleness
OK: vendored ontology matches pinned upstream ex4pm content
exit=0
```
(real CLI run: this machine's `~/ex4pm` is present and byte-matches the pin —
the real fresh verdict, not a skip.)

## Typed gaps / notes

- First run surfaced 7 `unused require ExUnit.CaptureIO` warnings
  (session-introduced); fixed by deleting the requires, rerun clean.
- Pre-existing, unrelated compiler warning in
  `lib/xaas/semantics/dataset_admission.ex:137` (Xaas.Semantics.DatasetAdmission)
  visible during the fresh lane build — not session-introduced, not touched.
- First compile used a fresh `MIX_BUILD_ROOT=_build-laneW869` (~6 min full
  compile; PromEx Grafana nxdomain warnings are sandbox network noise).
- `rm -rf _build-laneW869` was denied by the permission system; per lane rules
  the build root is **left for the coordinator** to delete at integration.
- No falsifier ran that corrupts the REAL vendored file in place (deliberate:
  (b) uses a temp copy; mutating the pin would violate preserve-O).

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=<any> \
  mix test test/xaas/ontology/staleness_task_court_test.exs
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  mix xaas.telemetry.check_ontology_staleness   # requires ~/ex4pm or EX4PM_REPO_PATH
```
