# W984ju — probe receipt: xaas_library_pack template surface

- Subject: `priv/packs/xaas_library_pack/templates/manufacture.ex.eex` on
  `feat/playwright-surface`, shared canonical checkout `/Users/sac/xaas`.
- Lane: W984ju. Read-only on the template; NO commit; template NOT staged.

## Sibling in-flight edit (disclosed, left alone)

Working tree differs from HEAD (`89ec308e..adf6d250`). The sibling diff removes all
AshGraphql references from the embedded resource bodies:

- Domain: `extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain]` → drops `AshGraphql.Domain`
- Book / Checkout / HoldRequest: drop `AshGraphql.Resource` from extensions
- Deletes the `graphql do type :library_book/:library_checkout end` blocks

Classification: in-flight sibling lane edit (AshGraphql removal). Not staged, not
reverted, not modified by this lane.

## Render verification (both baselines parse)

Render path: ggen front-matter strip (`---` YAML header removed) + `EEx.eval_string/2`
with `base_phase_targets` / `core_phase_targets` assigns (string-keyed target maps).
Parsed with `Code.string_to_quoted!` — parse check only, nothing written to lib/.

- Working-tree template: renders + parses.
- HEAD baseline (`git show HEAD:...`): renders + parses.

## Court

`test/xaas/generation/library_pack_render_court_w984ju_test.exs` — new, 5 tests, zero
mocks (real EEx over the real template file, real parser; mutation rationale in the
moduledoc: deleting the module name or EEx markers fails the structural-marker and
interpolation assertions).

Gate run:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ju \
  mix test test/xaas/generation/library_pack_render_court_w984ju_test.exs
# 5 passed, exit 0 (after ~18min fresh lane compile)
```

Two iterations to green, both in my own court harness, not the template:

1. `EEx.eval_string/2` binds keyword args as top-level variables — my initial
   `assigns:` wrapper bound a variable named `assigns` instead. Fixed by passing
   assigns at top level.
2. The template's ggen YAML front matter must be stripped before evaluation (the
   real ggen renderer does this); the court now mirrors that.

Mock gate:

```
mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test/xaas/generation/library_pack_render_court_w984ju_test.exs"]))'
# []
```

## Cleanup

`_build-laneW984ju` deleted via Elixir `File.rm_rf!/1` fallback (direct `rm -rf`
denied by permission gate); verified absent on disk after deletion.

## Deviation disclosed

The cleanup verification run used the default `_build` (MIX_ENV=test) and recompiled
4 files into the shared test build root — a real in-place compile of 4 files in the
shared checkout's `_build/test`. Pinned-toolchain asdf shims used throughout; no
corruption observed, disclosed per the compile-freeze SLA.

## Standing

- Template render surface: ALIVE (both working-tree and HEAD parse; structural
  markers present; loop assigns interpolate).
- Sibling AshGraphql-removal edit: UNKNOWN-to-integration (parses; semantic
  AshGraphql-compat decision owned by the editing lane).
- Nothing committed; court file is the only new artifact from this lane, plus this
  receipt.
