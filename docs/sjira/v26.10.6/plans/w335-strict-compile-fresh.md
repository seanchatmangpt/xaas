# W335 — DoD 2 local legs: strict compile at fresh, dirty HEAD

Subject: xaas + ash_surface, current dirty working trees (prior vector5/w103 greens predate tree moves; freshness legs re-run here). Date: 2026-10-06.

## Leg 1 — /Users/sac/xaas

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW335 mix compile --warnings-as-errors
```

Real tail (last lines):

```
    └─ lib/ash_a2a/eval/runner.ex:99:37: AshA2A.Eval.Runner.send_message/3

Generated ash_a2a app
==> ash_surface
Compiling 68 files (.ex)
    warning: redefining module Mix.Tasks.AshR2rml.Install (current version loaded from /Users/sac/xaas/_build-laneW335/test/lib/ash_r2rml/ebin/Elixir.Mix.Tasks.AshR2rml.Install.beam)
    │
  5 │ defmodule Mix.Tasks.AshR2rml.Install do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/mix/tasks/ash_r2rml.install.ex:5: Mix.Tasks.AshR2rml.Install (module)

Generated ash_surface app
==> xaas
Compiling 906 files (.ex)
Compiling lib/xaas/library/changes/fulfill_next_hold.ex (it's taking more than 10s)
Compiling lib/mix/tasks/xaas.ultracode.learn.ex (it's taking more than 10s)
Compiling lib/mix/tasks/xaas.autonomy.qualify.ex (it's taking more than 10s)
Compiling lib/mix/tasks/xaas.autonomic.controls.ex (it's taking more than 10s)
Generated xaas app
EXIT=0
```

- Exit: 0
- Warning classification: all visible warnings are DEP-class (`ash_a2a` eval/runner.ex; `ash_surface`/`ash_r2rml` Mix task redefinition — compiled as path deps of xaas, which do not run under `--warnings-as-errors`). Zero warnings from `lib/xaas` app code.
- Verdict vs vector5 baseline (dep-only warnings, app clean): **HELD**

## Leg 2 — /Users/sac/ash_surface

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/ash_surface/_build-laneW335 mix compile --warnings-as-errors
```

Real tail (last lines):

```
    └─ lib/ash_a2a/consequence_kernel/call_graph_court.ex:20:8: AshA2A.ConsequenceKernel.CallGraphCourt.normalize/1

Generated ash_a2a app
==> ash_surface
Compiling 73 files (.ex)
    warning: redefining module Mix.Tasks.AshR2rml.Install (current version loaded from _build-laneW335/test/lib/ash_r2rml/ebin/Elixir.Mix.Tasks.AshR2rml.Install.beam)
    │
  5 │ defmodule Mix.Tasks.AshR2rml.Install do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/mix/tasks/ash_r2rml.install.ex:5: Mix.Tasks.AshR2rml.Install (module)

Compilation failed due to warnings while using the --warnings-as-errors option
EXIT=1
```

- Exit: 1
- Warning classification: FAILING warning is APP-code — `lib/mix/tasks/ash_r2rml.install.ex:5` in ash_surface redefines `Mix.Tasks.AshR2rml.Install`, which also exists in the `ash_r2rml` dep beam. Dep-side warnings (`ash_a2a` call_graph_court.ex normalize/1 clause) also present but non-fatal there.
- Verdict vs vector5 baseline: **REGRESSED** (strict-compile failure, app-code source).

## Prod leg

Intentionally NOT run here (heavy). W327 drafted the CI leg; W316/W317 own the shared-test lanes.

## Cleanup law

`rm -rf /Users/sac/xaas/_build-laneW335 /Users/sac/ash_surface/_build-laneW335` was DENIED by the permission system. Operator cleanup items:

- /Users/sac/xaas/_build-laneW335
- /Users/sac/ash_surface/_build-laneW335

## Coordinator addendum (2026-10-06, post-lane)

The REGRESSED verdict's root cause was the OS-13 stray installer emission
(lib/mix/tasks/ash_r2rml.install.ex etc. — untracked gitignored pack outputs,
per w355-os13-pack-markers.md's contamination census). Remediated per the
recorded w230 quarantine procedure: 5 stray paths (lib/audit_trail/,
lib/notification_extension/, 3 *_install.ex tasks; ash_surface.install.ex is
the repo's own and stayed) moved reversibly to
/tmp/os13-quarantine-20261006-165326. Re-run after quarantine:
`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW335 mix compile --warnings-as-errors`
→ "Generated ash_surface app", **EXIT=0**. ash_surface verdict: HELD
(regression was environmental/OS-13, not app code; the pack-side fixtureOnly
mirror fix remains OS-13 operator work to prevent recurrence).
