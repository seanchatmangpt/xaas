# W141 Drift-Regen Receipt (E3 class, v26.10.6)

- Lane: W141 integration, 2026-10-06, repo /Users/sac/xaas, branch feat/playwright-surface
- Task: refresh W73-generated artifacts (`mix xaas.ash_surface`), rerun E3 drift-guard tests, classify persisting failures.

## Commands + exits (all real, pinned toolchain asdf elixir 1.20.2 / OTP 28.5.0.2)

1. `mix xaas.ash_surface` (dev env): FAILED — `UndefinedFunctionError AshA2A.Dsl.dsl_patches/0` during compile.
2. `mix deps.compile ash_a2a --force` (dev): "Generated ash_a2a app" (warnings only).
3. `mix xaas.ash_surface` (dev): FAILED — `AshA2A.Dsl.dsl_patches/0` persists.
4. `MIX_ENV=test mix deps.compile --force` (all deps): ok.
5. `MIX_ENV=test mix xaas.ash_surface` (shared `_build`): FAILED — `AshR2RML.Resource.Info.mapping/1 undefined (Xaas.A2a.Agent)`.
6. `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW141 mix xaas.ash_surface` (isolated lane build root, cold compile ~18 min): **EXIT 0** — wrote
   `priv/ash_surface/{aria.json,live_view.json,surface_contract.json,ash_surface_runtime.mjs,xaas_ash_surface_client.mjs}` (mtime 13:49:41; 5 files, +18/−10 vs HEAD).
7. E3 test run (`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW141 mix test <7 E3 files>`): **19/30 passed, 10 excluded, Failed: 11** — same 11 failures as pre-regen.

## Root cause of the build failures (new finding, not drift-guard)

Shared `_build` was corrupted by CONCURRENT MIX PROCESSES UNDER OTP 29 (erts-17.1) while the pinned
toolchain is OTP 28 (`.tool-versions`: erlang 28.5.0.2). Observed live: 4+ beam.smp processes on
erts-17.1 running mix against `/Users/sac/xaas/_build` during this lane's runs (build-lock contention
messages naming foreign PIDs). "UndefinedFunctionError … mapping/1 is undefined" was a symptom of the
mixed-toolchain build state, NOT a real dep API skew: `AshR2RML.Resource.Info.mapping/1` exists at
`deps/ash_r2rml/lib/ash_r2rml/resource.ex:548` and exports `mapping: 1` in a clean build.

Standing: shared `_build` and `_build/dev` are BUILD_BROKEN (mixed OTP28/OTP29 beams). Any lane that
ran mix without MIX_BUILD_ROOT isolation under OTP 29 caused this. Repair requires a coordinated
`mix deps.compile --force` (or `_build` wipe + rebuild) under the pinned toolchain with no other lane
compiling — coordinator-level transition, not a lane-level fix.

## Post-regen E3 classification (all 11 failures persist — regen cleared NONE of them)

The ash_surface generator's outputs are not inputs to any of the 11 failing guards; the failures are
test-pinned constants and config-vs-test drift:

- **regen-drift**: none found in E3. (W68b's premise that a W73 regen would clear E3 is REFUTED on this subject.)
- **count-drift** (test-pinned constants vs real corpus growth):
  - Igniter.CatalogTest 6 failures: test pins `{:ok, 137}`; real refusals schema projects **138** (wave added a refusal code). Fix = regenerate the pinned constant to 138 (test-side edit, outside this lane's ownership).
  - TopologyGuardTest: live tree scan now finds 3 `:shadow_topology` offenders — `priv/zcode_plugin/marketplace/xaas-fabric/commands/ultracode.md`, `priv/zcode_plugin/templates/command-ultracode.md.tmpl`, `test/xaas/sjira/yield_test.exs` (wave added 2 new ~/wt-referencing files; W68b saw only yield_test.exs). Fix = regenerate guard corpus or clean the files (owning lane).
  - W68b E3-37 ("28 open orders > 20 bound") now PASSES (bound test not among the 11) — bound-exceeded cleared on its own since the W68b run.
  - Config-vs-test drift (3 + profile-sense): `SjProgramRegistryTest` — dev config declares profile `ggen-ecosystem-courts` with no matching jira_dir profile; `autofde-lab` resolves to `/Users/sac/autofde-lab` but the test expects `~/xaas/worktrees/repos/autofde-lab`; suite env allowlist missing entries. Registry/config regen class, not artifact regen.
- **bound-exceeded**: none currently red (E3-37 self-cleared).

## Ownership

This lane owns only: regenerated `priv/ash_surface/*` (5 files, 13:49:41) and this receipt. No hand
edits to tests/config, no git operations performed.

## Replay

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW141 mix xaas.ash_surface
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW141 mix test test/xaas/topology_guard_test.exs test/xaas/igniter/igniter_catalog_test.exs test/xaas/ultracode/autonomic_test.exs test/xaas/ultracode/autonomic_multi_repo_test.exs test/xaas/ultracode/autonomic_backlog_script_test.exs test/xaas/ultracode/sj_program_registry_test.exs test/xaas/ultracode/autonomic_profile_sense_test.exs
```
(Build root deleted after receipt per cleanup law; replay cold-compiles ~18 min.)
