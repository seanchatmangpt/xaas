# W102 Receipt — ash_surface full-suite run (v26.10.6 convergence)

- **Date**: 2026-10-06
- **Repo**: /Users/sac/ash_surface, branch `main` @ `db5a889` ("feat(surface): commit Tokyo-Depeg burn-in surface manifest + W7 court (EA127)"), dirty tree (~40 modified lib/docs/config files, 30 modified test files, untracked `test/ash_surface/a2a_bridge_test.exs`)
- **Commands (real output, no fixes, no git mutations)**:
  - `cd /Users/sac/ash_surface && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test 2>&1 | tail -20`
  - `cd /Users/sac/ash_surface && npm test 2>&1 | tail -4`
- **Relation to baseline**: W19's 1280-green baseline; tree since changed by W43 (a2a bridge), W66 (JS projector), W93 (changelog), W90 (re-pin, if landed).

## Counts (verbatim)

### mix test

```
Finished in 24.1 seconds (10.8s async, 13.2s sync)

Result: 1288/1304 passed (48/48 doctests, 23/23 properties, 1217/1233 tests)
Failed: 16 tests
```

### npm test

```
ℹ pass 367
ℹ fail 0
ℹ cancelled 0
ℹ skipped 4
ℹ todo 0
ℹ duration_ms 303994.340167
```

## Failure classification: 16/16 lane-attributed (post-baseline introduction), 0 pre-existing

All 16 mix-test failures sit in exactly 4 test files that are **not part of the tracked suite and not present at the W19 baseline** — they are explicitly listed in `.gitignore` lines 39-42:

```
39  test/ash_r2rml_composition_test.exs
40  test/ash_surface_composition_test.exs
41  test/audit_trail_composition_test.exs
42  test/notification_extension_composition_test.exs
```

Verified: `git ls-files --error-unmatch test/ash_surface_composition_test.exs` → "did not match any file(s) known to git"; `git check-ignore -v` confirms all 4 ignored at those lines. Total test count moved 1280 → 1304 (+24); the 16 failures are new tests introduced after the baseline, not regressions in existing tests.

### The 16 failing tests

4 per file × 4 files (AshSurface / AuditTrail / NotificationExtension / AshR2RML `ResourceCompositionTest`):

1. test the compiled fixture actually carries the `<Ext>.Resource` extension
2. test `<Ext>.Resource.Info` returns real, non-nil compiled state for the fixture
3. test composes with real ash_graphql introspection
4. test composes with real ash_json_api introspection

### Root causes observed (compile warnings in the failing runs)

1. `AshSurface.Resource.Info.compiled/1 is undefined (module AshSurface.Resource.Info is not available or is yet to be defined)` — the Spark extension does not generate an `Info` module; the tests call one that does not exist. Same shape for AuditTrail / NotificationExtension / AshR2RML variants.
2. `setup` MatchError: the fixture setup pattern `[{fixture_module, _bytecode}] = Code.compile_string(@fixture_source)` no longer matches — compiling a Spark-extension resource returns multiple `{module, bytecode}` pairs (e.g. `Inspect.Ash_surfaceCompositionFixture` protocol consolidation impls alongside the fixture itself), so the single-element match fails before any assertion runs. Corroborated by "Inspect protocol has already been consolidated" warnings for `Tdb.BurnIn.Resources.RefusalLedger` / `AlignmentCosts` in the same run.
3. The `composes with real ash_graphql/ash_json_api introspection` tests assert `function_exported?(Ash_graphql.Resource.Info, :type, 1)` / `Ash_json_api.Resource.Info, :type, 1` and fail because those Info modules are not loaded/available in the test env as written.

### Lane attribution

- None of the 4 failing files matches the named lane scopes (W43 a2a bridge, W66 JS projector, W93 changelog, W90 re-pin). They are `.gitignore`d scratch files introduced post-baseline by an unidentified lane or probe; the ignorer clearly knew their status.
- **W43 lane surface is green**: its untracked `test/ash_surface/a2a_bridge_test.exs` (the only untracked, unignored test file) contributed 0 failures in the full run.
- **W66 lane surface is green**: `npm test` 367 pass / 0 fail (4 skipped by design).

## Standing

- Tracked suite (mix): effectively **clean** — every tracked test passes; the 16 failures are confined to ignored scratch files.
- JS conformance surface: **green** (367/367 run, 4 skipped).
- Open items, no fixes performed per instructions: decide (a) delete or (b) repair-then-track the 4 ignored composition test files; W43's `a2a_bridge_test.exs` remains uncommitted.
