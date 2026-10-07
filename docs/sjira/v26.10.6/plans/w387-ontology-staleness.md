# W387 — ex4pm ontology staleness task witness (v26.10.6 convergence)

Lane: W387 · Repo: /Users/sac/xaas @ feat/playwright-surface · Date: 2026-10-06

## Source notes

`lib/mix/tasks/xaas.telemetry.check_ontology_staleness.ex`:
- Inputs: none (no args, no pin file arg). Config-driven via
  `config :xaas, :ex4pm_ontology_check` (`repo_path` overridable via `EX4PM_REPO_PATH`).
- Delegates to `Xaas.Ontology.Ex4pmStaleness.check/0`.
- Exit contract: match → prints OK, exit 0; sibling repo absent → prints
  UNSUPPORTED (skipped), exit 0; pinned SHA unreachable / path missing /
  content mismatch → remediation text + Mix.raise (non-zero exit).
- Does not run `app.start` (pure check). No test mocking; the test slice
  shells out to real git.

## Real executions (lane build root `_build-laneW387`)

### 1. Task run
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW387 \
  mix xaas.telemetry.check_ontology_staleness
```
Tail (real):
```
==> xaas
Compiling 906 files (.ex)
...
Generated xaas app
OK: vendored ontology matches pinned upstream ex4pm content
EXIT=0
```
(Full fresh compile in the lane build root; compiled clean.)

### 2. Test slice — `test/xaas/ontology/ex4pm_staleness_test.exs`
Default run: `Result: 0 tests, 6 excluded` (tests tagged `@moduletag :external`).
With `--include external`:
```
......
Result: 6 passed
EXIT=0
```
6/6 passed on real git against the pinned ex4pm sibling repo.

## Verdict

**Task ALIVE** — exit contract honored exactly as documented: OK + exit 0 on
match; test slice 6/6 passed (`--include external`).

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW387` was **denied by the permission
system** (twice). Lane build root `_build-laneW387` REMAINS on disk at
`/Users/sac/xaas/_build-laneW387` — coordinator must delete it at
integration (per cleanup law, before final commit).
