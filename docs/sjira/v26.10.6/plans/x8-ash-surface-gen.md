# X8 — ash-surface generation path audit (v26.10.5)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface` `d1db2b03` (integration base per `_LANES.md`).
Scope: commits `02ce3776` (EA34) and `d1db2b03` (EA35). Read-only audit; MIX_ENV=test only.

## Standing: PARTIAL_ALIVE

Full-app generation works on this exact tree (commit falsifiers observed at EA35,
artifacts verified on disk this session):

- `priv/ash_surface/xaas_ash_surface_client.mjs` + `ash_surface_runtime.mjs` pass
  `node --check` (both OK, verified 2026-10-06).
- `surface_contract.json`: 410 actions, `generatorIdentity: ash_surface:v26.10.1`,
  `manifestDigest 9336b804…`. `aria.json`/`live_view.json` present and committed.
- Full-app run passes `namespace_prefix: "Xaas"` + a manifest-derived
  `namespace_names` override map (only for short-name collisions) through
  `AshSurface.Projectors.JS.project_ir/2`; pack-scoped `--resource` runs stay
  unprefixed to keep committed `priv/ash_surface/conference/` artifacts byte-stable.
- `Xaas.Accounts.Token` action renamed `:revoked?` → `:is_revoked` with
  `is_revoked_action_name :is_revoked` pinned in the token revocation DSL.
- EA34 prod gate: ash_graphlaw path dep un-pinned from `only: [:dev, :test]`,
  `Application.compile_env` in `Xaas.AshTypescriptManifest`, `mix.exs` alias
  unquoted — `MIX_ENV=prod … mix compile --warnings-as-errors` exit 0 (per commit;
  not re-run this session, read-only lane).

## Test coverage (real run, MIX_ENV=test)

- `/Users/sac/xaas/test/xaas/chicago/surface/command_center_adapter_test.exs` —
  9 passed, 0 failed (2026-10-06). Covers the AshSurface *standing* read model
  (CommandCenterAdapter), not the generator.
- The generation pipeline itself has **zero xaas-side test coverage**. No test file
  matches `ash_surface`/`AshTypescript` except the adapter test. Generator tests
  live only in the `~/ash_surface` path dep (`test/ash_surface_test.exs`,
  `test/js`, `test/conformance`).

## Gaps → v26.10.5 feature-complete

1. **No xaas-side generator test.** `Mix.Tasks.Xaas.AshSurface` (namespace_names
   derivation, prefix branching, refusal exit 1 path, `--resource` filter) is
   untested in xaas. Plan: ExUnit that runs the pipeline in-process against a
   temp `target_dir` override — needs a `target_dir`/`out_dir` opt plumbed
   through the task (currently hard-coded `@out_dir`), else it clobbers
   `priv/ash_surface/`.
   Acceptance falsifier: revert `js_projector_opts/2` to EA34 shape → test fails
   with `{:unsafe_js_namespace, "Object"}`.
2. **`:is_revoked` rename untested in xaas.** No xaas test references the action;
   only the ash_authentication dep suite exercises revocation. Plan: one Chicago
   test creating a real revocation token and calling `:is_revoked` via Ash.
3. **No committed-artifact drift guard.** A resource change silently makes
   `priv/ash_surface/*.mjs|json` stale; nothing in CI re-runs `mix xaas.ash_surface`
   and diffs. Plan: CI/test stage that regenerates and asserts byte-identical
   (commit claims byte-determinism; make it witnessed).
4. **Prod-compile gate not wired into CI** (EA34 falsifier was run once, by hand).
   Plan: add a `MIX_ENV=prod mix compile --warnings-as-errors` CI leg or a
   test-env equivalent.
5. **surface digest not persisted in the committed contract.** The commit message
   digest `7b9a58ce…` appears nowhere in `surface_contract.json` on disk
   (`manifestDigest` is present, surface digest is runtime-only). Plan: include
   `surface.digest` in the contract JSON so drift detection has a keyable value.
6. **Playwright wiring (lane mission).** The generated
   `xaas_ash_surface_client.mjs` is served at `/ash_surface` but no Playwright
   spec exercises it; coordinate with X1 lanes' spec gap plan.
