# W158 receipt — full suite WITH token (closes W68b E1 class)

- Subject: repo /Users/sac/xaas, branch `feat/playwright-surface`, HEAD `d1db2b03179975213c14663b9dbd86b5ac2a14cf` (dirty tree, multi-lane fan-out in progress)
- Date: 2026-10-06, ~14:45 PDT
- Command (via wrapper `/tmp/w158_run.sh` so env survives backgrounding):
  `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token MIX_ENV=test mix test`
  (asdf Elixir 1.20.2 / OTP 28, per repo pin)
- Full log preserved: `/tmp/w158_full2.log` (attempt 3; attempts 1-2 superseded: attempt 1 output
  lost to a tail-only pipe, attempt 2 aborted on a transient syntax error in
  `test/xaas/ultracode/semantic_replay_test.exs:495` — a lane's mid-edit state, clean on retry)

## Counts (verbatim)

```
Finished in 1141.4 seconds (233.7s async, 907.6s sync)

Result: 3125/3230 passed (6/6 doctests, 3119/3224 tests), 36 skipped, 91 excluded
Failed: 105 tests
```

## Failure classification (105 reported; 99 failure headers captured in log)

### Class E — INTERNAL_API_TOKEN env-var pollution across async tests: 87 failures
This closes the W68b "E1 class" (17 env-gated failures): with the token set at launch, 87
failures remain and they are NOT "token missing at launch" — the token WAS set (wrapper export).
The failure mechanism is test-isolation: `System.delete_env("INTERNAL_API_TOKEN")` inside async
tests (`test/xaas_web/plugs/require_internal_api_token_test.exs:25` in `without_env_token/1`,
and `test/xaas_web/execution_fabric_controller_test.exs:180`) deletes a **process-wide** env var
while sibling async tests run concurrently and then call `System.fetch_env!("INTERNAL_API_TOKEN")`
→ `System.EnvError`, or hit the plug's fail-closed 503 instead of expected 401.

Signatures:
- 72 x `** (System.EnvError) could not fetch environment variable "INTERNAL_API_TOKEN" because it is not set`
  (heaviest files: execution_fabric_controller_test.exs 28, marketplace_provider_controller_test 7,
  approval_backup_retention_change_controller_test 7, route_orgs_custom_domain_controller_test 6,
  execution_fabric_surface_test 6; spread over 15 files)
- 6 x `** (RuntimeError) expected response with status 401, got: 503, body: {"error":"internal_api_misconfigured",...}`
- 9 x `assert conn.status == 401` → `left: 503, right: 401`

E-class files (15): execution_fabric_controller_test.exs (28 EnvError + 6 503-RuntimeError),
require_internal_api_token_test.exs (7), ontop_proxy_plug_test.exs (3), book_embedding_vector_regression_test.exs (1),
ocel_envelope_avatars_test.exs, marketplace_provider_controller_test.exs (7), route_orgs_custom_domain_controller_test.exs (6),
approval_* controller tests (25), execution_fabric_surface_test.exs (6).

### Class D — drift: code calls missing module/function (E3 drift class, persists): 10 failures
- 5 x `Xaas.Ultracode.SemanticWaveTrigger.enqueue/1` undefined — called from
  `lib/xaas/ultracode/semantic_work.ex:282` (SemanticJiraBridgeCrownTest x5, incl. crown end-to-end test)
- 2 x `Xaas.Ultracode.ItemRuns.open!/1` undefined — called from test helper `completed_run!/1`
  (CapabilityResolverExecutionTest)
- 2 x `AshR2RML.Resource.Info.mapping/1` undefined — `ash_surface/compiler/semantic.ex:53`
  (AshSurfaceGeneratorTest, AshSurfaceDriftGuardTest; ash_r2rml 26.9.28 vs ash_surface 26.10.6 skew)
- 1 x `Xaas.Class...WriteActorResolutionAudit.write/1` undefined — `lib/xaas_web/a2a/next_read_user_agent.ex:85`
  (OcelEnvelopeAvatarsTest "avatar 2")

### Class F — expectation drift (test asserts stale shape): 2 failures
- Xaas.Witness.CatalogTest `list_by_algorithm` — match failed on `%Xaas.Witness.CertifiedReceipt{}` shape
- CapabilityResolverExecutionTest "anti-vacuity" — `Autonomic.resolve_and_dispatch` returned
  item not `status: :done`

### Residual — build contention (lane-active): 6 of the 105, not per-test classified
Log shows two mix processes contending for the shared `_build/test` lock ("Waiting for lock on
the build directory (held by process 3662)") and a protocol-consolidation crash writing
`_build/test/lib/xaas/consolidated/Elixir.Inspect.beam` (File.Error) — consistent with a
concurrent lane compiling into the same build root. The residual 6 failures' headers fell outside
the per-block capture; classify as BUILD-CONTENTION(lane-active), not E/D/F.

## Verdict

- W68b E1 class (17 env-gated failures) superseded: with the token present, the env-gated class
  is actually 87 failures and its cause is async test isolation (`System.delete_env` of a
  process-wide var), not a missing launch token. Setting INTERNAL_API_TOKEN at launch does NOT
  fix them.
- E3 drift class persists as predicted (10 failures, missing module/function — regeneration/W141
  dependent).
- No fixes applied, no git operations.
