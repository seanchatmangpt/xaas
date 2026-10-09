# XaasWeb.Router route table
GENERATED — do not edit. Source of truth: `lib/xaas_web/router.ex`.
Regenerate: `python3 scripts/gen_router_route_table.py`.
Verify: `python3 scripts/gen_router_route_table.py --check` (byte-identical re-extract).

| Line | Verb | Path | Controller / Plug | Action |
|---|---|---|---|---|
| 64 | get | `/` | `PageController` | home |
| 65 | live | `/next-read` | `NextRead.ReaderLive` | — |
| 66 | live | `/case-studies/wd-fa` | `WdFa.CaseStudyLive` | — |
| 67 | get | `/case-studies/wd-fa/stogaf.json` | `WdFaStogafController` | show |
| 68 | get | `/case-studies/wd-fa/context/:case_id` | `WdFaContextController` | show |
| 69 | live | `/chicago` | `Chicago.DrillDownLive` | — |
| 70 | live | `/witness` | `WitnessLive` | — |
| 71 | live | `/chicago/seller` | `Chicago.SellerLive` | — |
| 72 | live | `/marketplace-pplan` | `MarketplacePplanExplorerLive` | — |
| 73 | live | `/marketplace-catalog` | `MarketplaceCatalogLive` | — |
| 84 | post | `/webhooks/stripe` | `StripeWebhookController` | receive |
| 99 | get | `/internal-api/capability_liveness_regressions` | `CapabilityRegressionsController` | index |
| 100 | get | `/internal-api/ocel_summary` | `OcelSummaryController` | index |
| 106 | get | `/internal-api/eu-ai-act/pack` | `EuAiActExportController` | index |
| 107 | get | `/internal-api/prometheus/query` | `PrometheusQueryController` | query |
| 108 | get | `/internal-api/health` | `HealthController` | index |
| 109 | post | `/internal-api/rpc/run` | `AshTypescriptRpcController` | run |
| 110 | post | `/internal-api/rpc/validate` | `AshTypescriptRpcController` | validate |
| 116 | post | `/internal-api/execution/hooks/:event` | `ExecutionFabricController` | hook |
| 117 | post | `/internal-api/execution/mcp` | `ExecutionFabricController` | mcp |
| 126 | post | `/internal-api/execution/runs` | `ExecutionFabricController` | create_run |
| 134 | get | `/internal-api/execution/epochs/:epoch_id/receipts` | `ExecutionFabricController` | receipts |
| 144 | get | `/internal-api/fabric/probe` | `FabricController` | probe |
| 145 | post | `/internal-api/fabric/admit` | `FabricController` | admit |
| 146 | post | `/internal-api/fabric/runs` | `FabricController` | submit |
| 147 | get | `/internal-api/fabric/epochs/:epoch_id/receipts` | `FabricController` | receipts |
| 148 | post | `/internal-api/fabric/actuate` | `FabricController` | actuate |
| 198 | mount | `/mcp/*` | `XaasWeb.McpScope (forwards AshAi.Mcp.Router)` | — |
| 218 | forward | `/a2a/zoe-event` | `XaasWeb.A2A.ZoeEventPlug` | — |
| 231 | forward | `/a2a/v1` | `XaasWeb.A2A.V1TransportPlug` | — |
| 236 | forward | `/a2a/` | `A2A.Plug` | — |
| 254 | get | `/api/workbench/ggen/health` | `GgenWorkbenchController` | health |
| 255 | post | `/api/workbench/ggen` | `GgenWorkbenchController` | run |
| 268 | forward | `/internal-api/sparql` | `XaasWeb.OntopProxyPlug` | — |
| 286 | forward | `/internal-api` | `XaasWeb.InternalApiRouter` | — |
| 330 | forward | `/api` | `XaasWeb.ApiRouter` | — |
| 350 | live_dashboard | `/dev/dashboard` | `Phoenix.LiveDashboard` | — |
| 351 | forward | `/dev/mailbox` | `Plug.Swoosh.MailboxPreview` | — |
| 352 | live | `/dev/dashboards/autofde-lab` | `XaasWeb.AutofdeLab.StatusLive` | — |
| 361 | live | `/system` | `System.CommandCenterLive` | — |
| 373 | mount | `/admin/` | `AshAdmin.Router (ash_admin mount)` | — |

Total: 41 route declarations (34 verb/live routes, 7 forwards/mounts).
