# W359 — Chicago presence pin (§1 row 8, RESOLVE-BY-TEST)

Lane W359, repo /Users/sac/xaas @ feat/playwright-surface @ d1db2b03 (uncommitted
working tree; W353's disposition named this test). Contract: only
`test/xaas/chicago/presence_pin_test.exs` (new) and this plan file written;
lib/ untouched.

## What landed

`test/xaas/chicago/presence_pin_test.exs` — plain ExUnit, `async: true`,
2 tests, arities verified against source before writing:

- `Xaas.Chicago` (`lib/xaas/chicago.ex`): `Code.ensure_loaded?/1` true +
  `function_exported?/3` for `subject/0`, `layers/0`, `cases/0`
  (arities confirmed by grep of def lines).
- `Xaas.Chicago.View` (`lib/xaas/chicago/view.ex`): loaded +
  `drill_down/0` exported.

The test's moduledoc carries the negative-shape falsifier: deleting/renaming
either module fails the pin, making the `{:refused, ...}` soft-gate branches at
`command_center_adapter.ex:81` and `drill_down_live.ex:68,408` provably dead
(they can only fire if a same-app core module is absent — i.e. an upstream
compile failure the build gate already catches). If the modules are ever
extracted to an external dep, the disposition flips to
degraded-mode-legitimate and the guards become lawful again.

## Receipt

- Exact subject: /Users/sac/xaas @ feat/playwright-surface @ d1db2b03 working tree.
- O/O*: W353 disposition (row 8 RESOLVE-BY-TEST) + direct reads of
  `lib/xaas/chicago.ex`, `lib/xaas/chicago/view.ex` def lines for arities.
- μ/diff: 2 files written (test + this plan), both handwritten; 0 lib/ edits,
  0 repairs to the test after first run.
- Commands/exits:
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW359 mix test test/xaas/chicago/presence_pin_test.exs`
  → exit 0. Real tail:
  ```
  Finished in 0.03 seconds (0.03s async, 0.00s sync)

  Result: 2 passed
  [os_mon] memory supervisor port (memsup): Erlang has closed
  [os_mon] cpu supervisor port (cpu_sup): Erlang has closed

  [exited with code 0]
  ```
  (First invocation exceeded the 600s foreground timeout on a cold
  `MIX_BUILD_ROOT` full-app compile and completed in the background; the test
  phase itself ran in 0.03s. No pinned-toolchain corruption: asdf shims first
  on PATH.)
- Verification ladder: narrow (targeted test file) — sufficient for a
  presence pin; no behavior changed.
- Standing: ALIVE — row 8 executed on the exact subject, 2/2 passed.
- Cleanup: `_build-laneW359` deletion DENIED by permission system during the
  lane session — directory left in place (437M after run); coordinator should
  delete it at integration per the cleanup law.
- Falsifiers: (a) remove/rename `lib/xaas/chicago.ex` or
  `lib/xaas/chicago/view.ex` → this pin fails; (b) `mix test
  test/xaas/chicago/presence_pin_test.exs` → must stay 2 passed.
- Coordinator action: close row 8 as RESOLVED-BY-TEST.
