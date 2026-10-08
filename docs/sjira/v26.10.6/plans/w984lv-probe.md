# W984lv — internal-api controller-set unclaimed-family probe

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (HEAD `1ba31a97` at lane start)
- **Mode**: unclaimed-family probe, read-only census + one new court file. NO commit.
- **Scope**: every controller the main router mounts on `/internal-api`, plus the
  `XaasWeb.InternalApiRouter` (AshJsonApi catch-all forward).

## Census — per-controller dispositions

Explicit routes on the `/internal-api` scope
(`lib/xaas_web/router.ex:96-139`):

| Controller | Routes | Disposition |
|---|---|---|
| `CapabilityRegressionsController` | GET capability_liveness_regressions | COVERED — `test/xaas_web/controllers/capability_regressions_controller_test.exs` (empty + real-regression branches) |
| `OcelSummaryController` | GET ocel_summary | COVERED — `ocel_summary_controller_test.exs` (real Ash action → real NDJSON) + `test/xaas/semantics/map_update_dual_safe_test.exs:119` (summarize/1 incl. empty) |
| `EuAiActExportController` | GET eu-ai-act/pack | COVERED — `eu_ai_act_export_controller_test.exs` + `eu_ai_act_export_deepening_test.exs` (refusals, 503 fail-closed, byte-determinism) |
| `PrometheusQueryController` | GET prometheus/query | COVERED — `prometheus_query_controller_test.exs` (allowlist, range rejection, live) + `prometheus_upstream_court_w984if_test.exs` (all 3 Req clauses) + `residue_court_w984eq_test.exs` (missing_query_param 400) |
| `HealthController` | GET health | COVERED — `health_controller_test.exs` + `health_court_test.exs` (14 tests: warmup, stale, timeout, raising, unconfigured, determinism) |
| `AshTypescriptRpcController` | POST rpc/run, rpc/validate | COVERED — `rpc/family_court_w984ho_test.exs` + `rpc_surface_deepening_test.exs` (both actions, auth floor, action_not_found, validate branch, determinism) |
| `ExecutionFabricController` | POST hooks/:event, mcp, runs; GET epochs/:id/receipts | COVERED — `execution_fabric_controller_test.exs`, `execution_fabric_surface_test.exs`, `execution_fabric_deepening_test.exs`, `execution_fabric_hook_depth_test.exs`, `quiescent_fabric_tie_test.exs` (W824) — auth tiers, rate limit, org scoping, all tool refusals, MCP envelope arms |
| `FabricController` | /internal-api/fabric probe/admit/runs/receipts/actuate | COVERED — `fabric_controller_test.exs` + `fabric_court_w984js_test.exs` (idempotency, long-poll, cross-org 404, actuate 403) |
| `OntopProxyPlug` | forward /sparql | COVERED — `sparql_proxy_court_w984kq_test.exs` + `plugs/ontop_proxy_plug_test.exs` |
| `InternalApiRouter` (AshJsonApi catch-all) | all `Xaas.Operations` resources declaring `routes` | PARTIALLY COVERED — only `capability_liveness_receipts` paths courted (`internal_api_router_test.exs`, `json_api_surface_court_test.exs`, `jsonapi_content_negotiation_test.exs`). The remaining JSON:API routes had ZERO test hits — see court below. |

Not mounted on `/internal-api` (out of scope, verified courted elsewhere):
`GgenWorkbenchController` (`/api/workbench`; `workbench_deepening_test.exs`),
`WdFaContextController`/`WdFaStogafController` (page scope;
`wd_fa_*_test.exs`), `StripeWebhookController`, `PageController`.

## Genuinely uncovered surface found (court target)

The AshJsonApi catch-all serves 8 more resources with `routes do` blocks
whose `/internal-api/...` paths appear in zero test files (verified by
`grep -rn "internal-api/incidents|audit_log_entries|castle|approval_k8s|route_castle" test/`
→ no hits):

- `Xaas.Operations.Incident` — GET index/read, POST create, PATCH update
- `Xaas.Operations.AuditLogEntry` — GET index/read
- `Xaas.Operations.RouteCastleDeploy` — GET index/read (read-only projection)
- `Xaas.Operations.ApprovalCastleVerbSchedule` — GET index/read (+ create/approve routes exist but untested here)
- `Xaas.Operations.CastleVerbInventoryGoals` — GET index/read (projection)
- `Xaas.Operations.RouteCastleRun`, `RouteCastleSchedule`, `RouteCastleSunset`,
  `CastleVerbInventoryComponents`, `CastleVerbFortune5Requirements`,
  `ApprovalK8sFaultRemediateSuggest` — same class, same zero-hit status, left
  for a follow-on lane (same fix pattern applies)

## Court

`test/xaas_web/controllers/internal_api_court_w984lv_test.exs` — 8 tests,
real ConnCase through the main router, real bearer token, real sandboxed
Postgres rows, zero mocks. Mutation rationale per test inline.

- a.  incidents index over the wire (real `Ash.create!` fixture)
- a2. incidents read by id + unknown id → real 404
- a3. POST /internal-api/incidents with no resolvable org actor → fail-closed 403
  (ActorOrgMatches; internal-api scope has no ResolveOrgActor, so the
  seventeenth-pass escalation fix must hold on this tier too)
- b.  audit_log_entries index + read (real internal-write-path fixture)
- c.  route_castle_deploy index + read (real projection row via Repo struct
  insert — resource has no Ash create action; `requested_by` is non-public
  so JSON:API omits it from rendered attributes, noted in-test)
- d.  approval_castle_verb_schedule index
- e.  castle_verb_inventory_goals index
- f.  401 floor on all three new read paths

## Gates (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984lv \
  mix test test/xaas_web/controllers/internal_api_court_w984lv_test.exs
→ 8 passed, 0 failures, exit 0 (8 dots, "Result: 8 passed")

mock gate (scan_mock_usage on the new file) → []
```

## Receipt fields

- identity: lane W984lv, file receipt `docs/sjira/v26.10.6/plans/w984lv-probe.md`
- μ/diff: 1 new test file (`test/xaas_web/controllers/internal_api_court_w984lv_test.exs`, handwritten), 1 new receipt. No lib/ changes.
- commands/exits: court run 8/8 exit 0; mock gate `[]`
- verification ladder: narrow (single court file) — full-suite run left to integration
- standing: ALIVE for the 8 courted routes on this exact subject; UNKNOWN for
  `RouteCastleRun`/`RouteCastleSchedule`/`RouteCastleSunset`/
  `CastleVerbInventoryComponents`/`CastleVerbFortune5Requirements`/
  `ApprovalK8sFaultRemediateSuggest` internal-api JSON:API routes (same class,
  follow-on)
- falsifiers (all held): (1) a courted route that 404s or renders no row →
  would fail; (2) removing the token floor → test f fails; (3) re-opening the
  incident create bypass → test a3 fails with 201
- standing of the census itself: every disposition above re-checked by grep at
  write time against `test/` on this exact checkout

## Cleanup

Lane build root `_build-laneW984lv` deleted after final gate (rm -rf; note in
lane report if denied).
