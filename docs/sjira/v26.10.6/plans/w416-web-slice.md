# W416 — final-tree web regression net (test/xaas_web/ + test/xaas/accounts/)

Branch: feat/playwright-surface @ d1db2b03179975213c14663b9dbd86b5ac2a14cf (canonical checkout, no commits).
Lane build root: `_build-laneW416` (cold build, deleted after run — see cleanup).

## 1. Command

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW416 \
  mix test test/xaas_web/ test/xaas/accounts/
```

Halted at compile: `test/xaas_web/controllers/prometheus_query_controller_test.exs`.

## 2. Failure — isolation rerun (verbatim classification)

```
== Compilation error in file test/xaas_web/controllers/prometheus_query_controller_test.exs ==
** (CompileError) test/xaas_web/controllers/prometheus_query_controller_test.exs: cannot compile
module XaasWeb.PrometheusQueryControllerTest (errors have been logged)
    (elixir 1.20.2) expanding macro: Kernel.if/2
    test/xaas_web/controllers/prometheus_query_controller_test.exs:51: XaasWeb.PrometheusQueryControllerTest (module)
    (elixir 1.20.2) expanding macro: Kernel.@/1
    test/xaas_web/controllers/prometheus_query_controller_test.exs:50: XaasWeb.PrometheusQueryControllerTest (module)
```

Classification: **REAL, not env.** Reproducible in isolation. The file carries +30 uncommitted
working-tree lines (the w155 typed-skip TCP probe, `git diff HEAD` confirms). `@tag skip:
if(prometheus_reachable?(), ...)` calls a module-private function inside a module-attribute value —
module attributes evaluate at compile time, where private functions are not callable → CompileError
every run, every env. This is an in-flight edit from another lane (references w408/w155 convention),
not committed tree state; committed HEAD version has no such lines.

Not env (test env is healthy: 377 other tests green in same build root, same env). Not baseline:
w329 recorded all web suites green on committed tree; this failure exists only in the uncommitted
in-flight diff. **NEW failure vs w317/w329/w347 baselines — finding.**

OS-17 vault guard: test-env unaffected, proven — `test/xaas/accounts/` (incl.
token_revocation_test.exs, the vault/token surface) ran green under the same build root; the guard
is prod-only and never fired in MIX_ENV=test.

## 3. Slice-minus-blocked-file run

```
mix test <all 71 remaining files> →
Finished in 38.7 seconds (4.4s async, 34.3s sync)
Result: 377 passed
```

0 failed, 0 skipped. Coverage: 72 web+accounts test files total, 71 executed.

## 4. Verdict

**Findings, not green:** web+accounts slice is green on 377/377 executed tests, but the slice is
not clean-at-final-tree — one file in the working tree does not compile:

- F1 (REAL, NEW vs baseline, blocks `mix test test/xaas_web/` wholesale): uncommitted w155
  typed-skip edit in `test/xaas/web/controllers/prometheus_query_controller_test.exs` uses
  `@tag skip: if(prometheus_reachable?(), ...)` — a private function invoked in a module-attribute
  value. Fix shape: compute at module compile time via a macro/module-attribute composition, or
  move the probe to `setup` + runtime `ExUnit.skip`-style tagging (module attributes cannot call
  private functions).

Owner: whichever lane owns the w155/w408 typed-skip conversion (not W416's contract to fix).

## 5. Cleanup

- `rm -rf /Users/sac/xaas/_build-laneW416` — DENIED by session permission gate (observed
  2026-10-06). Path remains on disk (~437M): `/Users/sac/xaas/_build-laneW416` (coordinator to delete).
