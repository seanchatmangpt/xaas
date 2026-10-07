# W342 — E2E Coverage Map (P3-2, coverage leg)

Repo: /Users/sac/xaas @ feat/playwright-surface. Read-only lane; this file is the only write.
Method: extracted every URL path from `page.goto` / `request.get|post` across all 22
`e2e/*.spec.cjs|ts` files, then verified each against `lib/xaas_web/router.ex` (incl. scope
prefixes, `forward` targets, endpoint plug_static mount, and the dev_routes `if` block).

## Router surface inventory (backing verified)

- Browser scope `/`: `/`, `/next-read`, `/case-studies/wd-fa`, `/case-studies/wd-fa/stogaf.json`,
  `/case-studies/wd-fa/context/:case_id`, `/chicago`, `/witness`, `/chicago/seller`,
  `/marketplace-pplan`, `/marketplace-catalog`
- `/webhooks/stripe` POST
- `/internal-api` explicit scope: `capability_liveness_regressions`, `ocel_summary`,
  `prometheus/query`, `health`, `rpc/run`, `rpc/validate`, `execution/hooks/:event`,
  `execution/mcp`, `execution/runs`, `execution/epochs/:epoch_id/receipts`
- `/internal-api/fabric`: `probe`, `admit`, `runs`, `epochs/:epoch_id/receipts`, `actuate`
- `/internal-api/sparql` → OntopProxyPlug forward
- `/internal-api` catch-all forward → `XaasWeb.InternalApiRouter` (AshJsonApi over
  Xaas.Operations; serves `/internal-api/capability_liveness_receipts` — verified at
  lib/xaas/operations/capability_liveness_receipt.ex:118-130 `json_api type/base`)
- `/api/workbench/ggen/health`, `/api/workbench/ggen` (token-gated workbench scope)
- `/api` forward → `XaasWeb.ApiRouter`
- `/mcp` → AshAi Mcp.Router mount (token + audit pipelines)
- `/a2a/zoe-event` → ZoeEventPlug; `/a2a/v1` → `XaasWeb.A2A.V1TransportPlug`; `/a2a/` → A2A.Plug
  catch-all (serves `/.well-known/agent-card.json`)
- `/ash_surface/*` → endpoint `plug_static` mount at `/ash_surface` from `priv/ash_surface`
  (lib/xaas_web/endpoint.ex:26-31)
- DEV-GATED (`if Application.compile_env(:xaas, :dev_routes)`): `/dev/dashboard`,
  `/dev/mailbox`, `/dev/dashboards/autofde-lab`, `/system`, `/admin` (ash_admin mount)

## Per-spec verdict table

| Spec | Paths exercised | Verdict |
|---|---|---|
| a2a-v1.spec.cjs | `/a2a/v1`, `/a2a/v1/.well-known/agent-card.json` (GET/POST/JSON-RPC) | COVERED (V1TransportPlug forward) |
| ash-admin-destroy.spec.cjs | `/admin/?domain=…&action_type=destroy…`, `/internal-api/capability_liveness_receipts?filter[…]` | DEV-GATED + COVERED (dev_routes `/admin`; AshJsonApi backing confirmed) |
| ash-admin-matrix.spec.cjs | `/admin/`, `/admin/?domain=…resource=…`, `/internal-api/capability_liveness_receipts` | DEV-GATED + COVERED |
| ash-admin-state-change.spec.cjs | same two surfaces as destroy | DEV-GATED + COVERED |
| ash-surface-client.spec.cjs | `/ash_surface/surface_contract.json`, `/ash_surface/xaas_ash_surface_client.mjs`, `/ash_surface/ash_surface_runtime.mjs` | COVERED (endpoint plug_static mount) |
| autofde-lab.spec.cjs | `/dev/dashboards/autofde-lab` (incl. typed 404 when dev flag off) | DEV-GATED |
| chicago-pplan-deep.spec.cjs | `/chicago`, `/chicago/seller`, `/marketplace-pplan` | COVERED |
| dev-routes.spec.cjs | `/dev/dashboard`, `/admin`, `/admin/?domain=…` | DEV-GATED |
| execution-fabric.spec.cjs | `/internal-api/fabric/actuate`, `/internal-api/fabric/probe` | COVERED |
| full_surface.spec.ts | `/`, `/next-read`, `/case-studies/wd-fa`, `/chicago`, `/chicago/seller`, `/marketplace-pplan`, `/marketplace-catalog`, `/system` (dev-gated leg) | COVERED (mixed: one dev-gated path — legitimately asserted <400 only when dev flag on) |
| ggen-workbench.spec.cjs | `/api/workbench/ggen/health`, `/api/workbench/ggen` | COVERED |
| internal-api.spec.cjs | `/internal-api/health`, `/internal-api/ocel_summary` | COVERED |
| marketplace.spec.ts | `/marketplace-catalog` | COVERED |
| mcp-a2a.spec.cjs | `/mcp` (JSON-RPC), `/a2a/.well-known/agent-card.json` (tokenless + authed), `/a2a/zoe-event/.well-known/agent-card.json` | COVERED + TOKENLESS-DEGRADED |
| next-read-ml.spec.cjs | `/next-read` | COVERED |
| smoke.spec.cjs | `/` | COVERED |
| sparql-proxy.spec.cjs | `/internal-api/sparql` | COVERED (OntopProxyPlug forward) |
| stripe-webhook.spec.cjs | `/webhooks/stripe` POST | COVERED |
| system-deep.spec.cjs | `/system` | DEV-GATED |
| wd-fa-cs2.spec.cjs | `/case-studies/wd-fa`, `/case-studies/wd-fa/context/known_firmware.json`, `/case-studies/wd-fa/stogaf.json` | COVERED |
| witness.spec.cjs | `/witness` | COVERED |
| zcode-cli-fabric.spec.cjs | `/internal-api/execution/mcp`, `/internal-api/execution/epochs/:epoch_id/receipts` | COVERED |

## Totals

- 22 specs mapped. COVERED (incl. mixed): 16; DEV-GATED pure: 3 (autofde-lab, dev-routes,
  system-deep); DEV-GATED + COVERED mixed: 3 (ash-admin specs); PHANTOM: 0.
- TOKENLESS-DEGRADED overlays: mcp-a2a (`/a2a/.well-known/agent-card.json` 503/401 fail-closed
  assertions) and the no-auth legs of ggen-workbench, internal-api, sparql-proxy,
  execution-fabric, zcode-cli-fabric (intentional 401/403 fail-closed legs).
- Phantom expectation held: **0 phantom routes**.

## Inverse coverage gaps (mounted surfaces with no spec)

- `/dev/mailbox` (Swoosh mailbox preview forward) — no spec touches it.
- `/internal-api/rpc/run` and `/internal-api/rpc/validate` (AshTypescriptRpcController) — no
  dedicated spec; only reachable indirectly if ash-admin specs' AshJsonApi reads don't count.
- `/internal-api/prometheus/query` — no spec.
- `/internal-api/capability_liveness_regressions` — no spec.
- `/internal-api/execution/hooks/:event` — no spec (mcp and runs paths are covered via
  zcode-cli-fabric; hooks is the uncovered sibling).
- `/internal-api/execution/runs` — no direct spec (covered only as a downstream effect of the
  zcode-cli-fabric MCP claim flow, if that flow routes through it).
- `/internal-api/fabric/admit`, `/internal-api/fabric/runs`, `/internal-api/fabric/epochs/:id/receipts`
  — only `probe` and `admit`-less `actuate`/`probe` covered by execution-fabric.spec; `admit`,
  `runs`, and the fabric receipts long-poll have no spec.
- `/a2a/zoe-event` message surface beyond the agent-card GET — only the `.well-known` GET is
  exercised (mcp-a2a.spec.cjs:142); no message POST.
- `/ash_surface` live view / ARIA artifacts beyond the 3 static files asserted in
  ash-surface-client.spec.cjs — any additional generated artifacts unexercised.
- `/next-read` POST-backed flows — next-read-ml covers the LiveView; any JSON/API POST path
  behind it unexercised (none found in router, so informational only).

## Receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface (single canonical checkout, no commits made).
- Commands: `ls e2e/`, router read (333 lines), path-extraction grep across 22 specs,
  targeted reads of ash-admin/zcode/witness/full_surface specs, endpoint.ex + internal_api_router.ex
  + capability_liveness_receipt.ex backing reads.
- Verdict: 0 phantom. All 22 specs map to real router (or endpoint-mount) backing.
