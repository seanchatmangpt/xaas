# W148 — Bridges + Ultracode targeted receipt (v26.10.6)

- Repo: `/Users/sac/xaas`, branch `feat/playwright-surface`, integration lane W148
- Date: 2026-10-06
- Command (verbatim):

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH \
GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test \
mix test test/xaas/bridges test/xaas/ultracode/origin_authority_test.exs \
  test/xaas/ultracode/semantic_drive_anchor_test.exs
```

- Exit code: **1**
- Test counts: **none — zero tests ran.** The run died in the compile phase,
  before the ExUnit runner started. There are no pass/fail numbers to report
  for `test/xaas/bridges` or the two ultracode files; any count here would be
  fabricated.

## Failure classification: BUILD_BROKEN (compile phase, upstream dep)

The compile aborts inside the local path dep **`ash_surface`**, not in xaas's
own `test/` tree:

```
==> ash_surface
Compiling 5 files (.ex)
    warning: redefining module AshA2A.Skill     (…/_build/test/lib/ash_a2a/ebin/…Skill.beam)
    warning: redefining module AshA2A.Argument  (…ash_a2a/…)
    warning: redefining module AshA2A.HddlOperator (…ash_a2a/…)
    warning: redefining module AshA2A.Dsl       (…ash_a2a/…)
** (EXIT from #PID<0.94.0>) an exception was raised:
    ** (UndefinedFunctionError) function AshA2A.Dsl.dsl_patches/0 is undefined or private
        (ash_a2a 26.10.4) AshA2A.Dsl.dsl_patches()
        (spark 2.7.6) lib/spark/dsl/extension.ex:2276: Spark.Dsl.Extension.__after_verify__/1
        (elixir 1.20.2) lib/module/parallel_checker.ex:292: Module.ParallelChecker.check_module/4
        (elixir 1.20.2 called "post-fix"; no fixes applied.
```

- Root cause: `ash_surface`'s `lib/ash_a2a/resource.ex` redefines four
  `AshA2A.*` modules already shipped in the hex dep `ash_a2a 26.10.4`; Spark's
  `__after_verify__` then resolves `AshA2A.Dsl.dsl_patches/0` against the dep
  version, where it does not exist → hard compile exit.
- Scope: whole `MIX_ENV=test` build is broken at this dep, so the bridges and
  ultracode suites are **BLOCKED**, not red. Pre-existing (not introduced this
  lane: the redefinitions carry a stale-beam warning pattern from a prior
  build state).
- Standing: **BLOCKED(BUILD_BROKEN, dep `ash_surface` / ash_a2a 26.10.4
  module-collision)**. Per lane rules: no fixes, no git.

## W163 rerun

Command: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/xaas/bridges test/xaas/ultracode/origin_authority_test.exs test/xaas/ultracode/semantic_drive_anchor_test.exs`

Real output (tail):

```
Finished in 35.7 seconds (0.00s async, 35.7s sync)

Result: 24 passed
```

Counts verbatim: 24 passed, 0 failures, 0 errors, 0 skipped.

Classification: no failures. The anchor's 2 mu_on_O pins PASS as expected (W116 rewrote
them as refusal pins); origin_authority 10/0 per W108 holds. W148's BUILD_BROKEN status
(collision, since cleared) is resolved — rerun is green. Note: Oban/Postgrex emitted
`FATAL 53300 (too_many_connections)` log lines during startup (shared dev Postgres
saturation from concurrent sessions); they did not affect any test outcome.
