# W837 — TS codegen drift court

Date: 2026-10-07. Repo: /Users/sac/xaas, branch `feat/playwright-surface`, HEAD `a0723bf6`.
Backlog: the generated TypeScript artifacts (`assets/js/ash_rpc.ts` 12064 B / 400 lines,
`assets/js/ash_types.ts` 33891 B / 939 lines, per W820's corrected counts) had no drift
court; the law says generated outputs must not drift from their generator without a graph
change.

## What was built

`test/xaas_web/ts_codegen_drift_court_test.exs` — Chicago-style (real generator, real
files, byte-level assertions on final state; no mocks):

1. **Drift court ×2**: invokes the REAL `ash_typescript.codegen` Mix task in-process
   (`Mix.Task.rerun`) with the task's documented `--output <tmp>/ash_rpc.ts` override
   (relocates the whole output set, deriving siblings by default name — see task
   moduledoc), then byte-compares both outputs against the tracked
   `assets/js/ash_rpc.ts` / `assets/js/ash_types.ts`. On drift the failure is typed:
   `DRIFT_ASSET_STALE: ... Repair by re-running: mix ash_typescript.codegen --output assets/js (never hand-edit the artifact)`.
2. **Determinism ×2**: two consecutive codegen runs into separate subdirectories must be
   byte-identical; typed failure `NONDETERMINISTIC_CODEGEN`.

Never touches the tracked artifacts (verified: `git status --porcelain assets/js` empty
after test runs); temp dirs removed in `on_exit`; Application env `:output_file` restored
in `on_exit`; `async: false` (task mutates app env).

## Executed evidence

Trial (CLI, prior to test authoring) — codegen into temp, MIX_ENV=test:
```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW837 \
    mix ash_typescript.codegen --output /tmp/w837-tmp/ash_rpc.ts
Generated xaas app        (exit 0)
ash_rpc.ts   12064 B      ash_types.ts   33891 B
$ cmp /tmp/w837-tmp/ash_rpc.ts assets/js/ash_rpc.ts && echo RPC_IDENTICAL
RPC_IDENTICAL
$ cmp /tmp/w837-tmp/ash_types.ts assets/js/ash_types.ts && echo TYPES_IDENTICAL
TYPES_IDENTICAL
```
Second pass → `DETERMINISTIC` (both files byte-identical across runs).

Court run (this file's subject):
```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW837 \
    mix test test/xaas_web/ts_codegen_drift_court_test.exs
Finished in 0.2 seconds (0.00s async, 0.3s sync)
Result: 3 passed
```
`git status --porcelain assets/js` after court run: empty (tracked artifacts untouched).

## Standing

ALIVE for the exact subject `test/xaas_web/ts_codegen_drift_court_test.exs` on
`feat/playwright-surface` @ `a0723bf6`: the court executes the real generator and
byte-compares real files; drift and non-determinism are typed failures naming the regen
command.

## Notes / typed gaps

- The task CAN run under MIX_ENV=test (contrary to the brief's contingency); no
  PARTIAL_ALIVE fallback needed.
- First court run failed 3/3 on a lane-authoring bug (the `--output dir/x.ts` override
  derives sibling files by their DEFAULT names, so `run1-ash_types.ts` never exists);
  fixed to per-run subdirectories. The failure itself witnessed the court kills real
  mismatches.
- Fresh build root took >500 s of dep compile before the first codegen ran; the court
  itself takes 0.2 s once built.
- Codegen also emits manifest files (`AshTypescript.Rpc.manifest_file()` paths) at their
  own configured locations — untouched by `--output` relocation; out of scope here.
- Regen command (canonical repair): `PATH=$HOME/.asdf/shims:$PATH mix
  ash_typescript.codegen --output assets/js` (dev or test env both exercised).
