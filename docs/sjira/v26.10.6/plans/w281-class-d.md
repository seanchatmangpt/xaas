# W281 — Class D Drift-Failure Adjudication (10 failures from W158)

Date: 2026-10-06 · Lane: W281 · Subject: `/Users/sac/xaas` @ `feat/playwright-surface` (working tree, uncommitted)

## Verdict: all 10 = stale-beam (shared `_build`), zero real drift

Every named function exists in `lib/` at the exact reported arity in the current
tree:

- `Xaas.Ultracode.SemanticWaveTrigger.enqueue/1` —
  `lib/xaas/ultracode/semantic_wave_trigger.ex:107,146,158` (3 clauses)
- `Xaas.Ultracode.ItemRuns.open!/1` — `lib/xaas/ultracode/item_runs.ex:88`
- `AshR2RML.Resource.Info.mapping/1` — exists in the `deps/ash_r2rml` info module
  (W230's quarantine of the shadowing dir removed the skew source)
- `Xaas.Library.Changes.WriteActorResolutionAudit.write/1` —
  `lib/xaas/library/changes/write_actor_resolution_audit.ex:39`

Consistent with stale compiled beams predating these definitions.

## Reproduction (MIX_ENV=test, pinned asdf toolchain, seed 281)

| File | Result |
|---|---|
| `test/xaas/ultracode/semantic_jira_bridge_crown_test.exs` | **5 passed, 1 excluded** (incl. all 5 former `enqueue/1` failure sites) |
| `test/xaas/ultracode/capability_resolver_execution_test.exs` | pass (within combined run) |
| `test/xaas/ash_surface_generator_test.exs` | pass (within combined run) |
| `test/xaas/ash_surface_drift_guard_test.exs` | pass (within combined run) |
| `test/xaas_web/ocel_envelope_avatars_test.exs` | pass (within combined run) |

Combined run of the latter four: **11 passed, 0 failures**.

Commands:
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/ultracode/semantic_jira_bridge_crown_test.exs --seed 281
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/ultracode/capability_resolver_execution_test.exs test/xaas/ash_surface_generator_test.exs test/xaas/ash_surface_drift_guard_test.exs test/xaas_web/ocel_envelope_avatars_test.exs --seed 281
```

## Disposition

- Test-side fixes: none required (0 files touched).
- Lib-side: none — `STOP` not invoked; no real UndefinedFunctionError exists.
- Both the `enqueue/1` and r2rml-skew groups reproduce clean under the pinned
  toolchain against the current build, confirming W230's r2rml quarantine closed
  the skew and W158's 10 Class D failures were beams from before the wave's
  lib changes landed in the shared build.

Standing: Class D resolved as stale-beam; no residual drift.

## W298 Class F closure

**Claim**: W158's Class F residual — CapabilityResolver anti-vacuity stale test
expectation — is already resolved on the current tree; no test edit was required.

**Adjudication** (2026-10-06, lane W298, exact subject /Users/sac/xaas @ d1db2b03, branch feat/playwright-surface):
Both candidate Class F surfaces were executed, not inspected:

1. `test/xaas/ultracode/capability_resolver_test.exs` +
   `test/xaas/ultracode/capability_resolver_execution_test.exs` (the anti-vacuity
   twin lives in the latter, test "anti-vacuity: with NO completed-run witness
   the same item reaches the dispatcher"): **28 passed, 0 failures**.
2. The `138` refusal-codes pin (not in the resolver file; it is
   `@refusal_count 138` in `test/xaas/igniter/igniter_catalog_test.exs`,
   "ingesting the REAL refusals schema projects exactly 138 codes") also passes:
   **10 passed, 0 failures**.

**Diagnosis**: the stale expectation was fixed by earlier v26.10.6-wave work
(likely d1db2b03 "unblock full-app generation (EA35 namespace plumbing)" and/or
the W158 Witness.CatalogTest fix); no further expectation update or product
defect exists at this SHA.

**Commands**:
- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/ultracode/capability_resolver_test.exs test/xaas/ultracode/capability_resolver_execution_test.exs` → `28 passed`
- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/igniter/igniter_catalog_test.exs` → `10 passed`

**Files touched by this lane**: this receipt only (no test edit needed; zero lib edits; no git ops).
