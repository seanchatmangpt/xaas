# W224 Drift-Authority Receipt — priv/ash_surface on-disk state vs HEAD

- Subject: /Users/sac/xaas @ branch feat/playwright-surface, HEAD d1db2b03
- Date: 2026-10-06
- Lane: W224 (integration), v26.10.6 convergence. Scope: read-only + this receipt only.
- Rules honored: no regen runs, no git mutations.

## (1) On-disk identity: W141's isolated-root regen

`git status --short priv/ash_surface` → 5 files modified:

```
 M priv/ash_surface/aria.json
 M priv/ash_surface/ash_surface_runtime.mjs
 M priv/ash_surface/ash_surface_runtime.mjs | 8 ++++----
 M priv/ash_surface/live_view.json            | 2 +-
 M priv/ash_surface/surface_contract.json     | 2 +- 
 M priv/ash_surface/xaas_ash_surface_client.mjs | 14 +++++++++++---
 5 files changed, 18 insertions(+), 10 deletions(-)
```

`git diff --stat` = **+18/−10 over 5 files** — exactly the W141 isolated-root
regen signature (+18/−10 vs HEAD). W73's shared-root regen is NOT on disk.
W141's regen is the on-disk state.

## (2) Drift guard on the CURRENT shared `_build`: RED

Command (real run, pinned asdf toolchain, MIX_ENV=test, shared `_build`):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
  test/xaas/ash_surface_drift_guard_test.exs \
  test/xaas/ash_surface_generator_test.exs
```

Result: `Result: 0/2 passed, Failed: 2 tests` (0.5s, sync).

Both tests crash identically during the regeneration step, BEFORE any
artifact-vs-HEAD comparison is reached:

```
** (UndefinedFunctionError) function AshR2RML.Resource.Info.mapping/1 is undefined or private
    (ash_r2rml 26.9.28) AshR2RML.Resource.Info.mapping(Xaas.A2a.Agent)
    (ash_surface 26.10.6) lib/ash_surface/compiler/semantic.ex:53: AshSurface.Compiler.Semantic.build/2
    ... compiler assemble → Mix.Tasks.Xaas.AshSurface.run/1
    test/xaas/ash_surface_drift_guard_test.exs:37
    test/xaas/ash_surface_generator_test.exs:42
```

## (3) Classification: cross-repo API skew, NOT artifact drift

Root cause is upstream dep skew, not a drifted on-disk projection:

- xaas `mix.exs` pins `{:ash_r2rml, git: .../ash_r2rml.git, ref: "0d5320f6c5e9a43bb3e8dcb0f30d301b1ebb64d7", override: true}`.
  Dep checkout HEAD = `0d5320f feat(obda): differential graph projection ...`.
  At that ref, `mapping/1` lives on `AshR2RML.Resource` (`deps/ash_r2rml/lib/ash_r2rml/resource.ex:548`); **no `AshR2RML.Resource.Info` module exists** (`deps/ash_r2rml/lib/ash_r2rml/resource/info.ex` — file absent).
- The generator is a path dep `{:ash_surface, path: "../ash_surface"}` =
  /Users/sac/ash_surface @ `db5a8899e feat(surface): commit Tokyo-Depeg burn-in surface manifest + W7 court (EA127)` (working tree dirty there, unrelated to this lane).
  Its compiler (`/Users/sac/ash_surface/lib/ash_surface/compiler/semantic.ex:53`) calls `R2RMLInfo.mapping(resource)` (alias for `AshR2RML.Resource.Info.mapping/1`).
- So the W141-generation toolchain (ash_surface @ db5a8899e) targets an
  ash_r2rml API (Resource.Info) that the xaas-pinned ash_r2rml ref (0d5320f)
  does not have. The shared `_build` deps are compiled from the xaas pin.

## Standing

- On-disk priv/ash_surface = **W141 isolated-root regen** (authoritative-by-signature; +18/−10).
- Drift guard on shared `_build`: **BLOCKED (RED)** — 0/2, crashes in regen phase.
- Failure class: **cross-repo API skew** (ash_surface @ db5a8899e expects
  `AshR2RML.Resource.Info.mapping/1`; xaas-pinned ash_r2rml @ 0d5320f exposes
  `AshR2RML.Resource.mapping/1`, no `Resource.Info` module). Not artifact drift;
  artifacts were never compared — regen crashes first.
- Remediation owner (not this lane): bump xaas `ash_r2rml` git ref to one that
  provides `AshR2RML.Resource.Info` (W141's replay env), or repoint the
  ash_surface path dep. Until then, the guard cannot certify either regen.
- No W73/W141 replay commands were run (lane rules: read-only).
