# Architecture Overview

This is the whole-system map for xaas: what the 8 Ash domains own, how the 3-tier
`/internal-api` (plus `/api`, `/mcp`, `/a2a`, and `/webhooks`) routing splits requests, and how the
cross-cutting mechanisms — actor/tenant resolution, audit trail, webhooks, Reactor, and the
Ontop SPARQL bridge — compose on top of that resource set. It links out to the narrower
existing explainers rather than re-deriving their content; read this first, then follow the
links for depth on any one topic.

## The 8 Ash domains

Defined in `lib/xaas/*.ex` (`use Ash.Domain`), resources counted directly from each domain's
real `resources do ... end` block (74 total):

| Domain | Module | Resources | What it owns |
|---|---|---|---|
| Accounts | `Xaas.Accounts` (`lib/xaas/accounts.ex`) | 5 | `User`, `Org`, `OrgMembership`, auth/PII data — deliberately unwired from `/api` (see below) |
| Billing | `Xaas.Billing` (`lib/xaas/billing.ex`) | 7 | Subscriptions and 6 maker-checker `Approval*` resources (pricing override, quota override, tier downgrade, SLA credit apply, patch SLA credit apply, invoice reconciliation approve) |
| Ledger | `Xaas.Ledger` (`lib/xaas/ledger.ex`) | 4 | Real financial ledger — `Balance`/`Account`/`Transfer` — deliberately unwired from `/api` (see below) |
| Marketplace | `Xaas.Marketplace` (`lib/xaas/marketplace.ex`) | 2 | `Provider` + its approval resource; multitenant via `actor_org_matches`/`actor_org_filter` checks |
| Operations | `Xaas.Operations` (`lib/xaas/operations.ex`) | 17 | `AuditLogEntry`, capability-liveness receipts, incident/route-castle lifecycle, and the AutofdePlanner cache/catalog/candidate/match resources |
| Platform | `Xaas.Platform` (`lib/xaas/platform.ex`) | 7 | `Webhook` + `WebhookDelivery` (outbound HMAC dispatch), plus platform-level approvals |
| Governance | `Xaas.Governance` (`lib/xaas/governance.ex`) | 27 | The largest domain: `FreezeWindow`, `AuditExportToken`, and the bulk of the `Approval*` maker-checker surface, including the 4 non-global-multitenancy resources (`ApprovalDrFailover`, `ApprovalLegalHoldRelease`, `ApprovalDeploymentQuarantine`, `ApprovalBackupRetentionChange`) |
| Library | `Xaas.Library` (`lib/xaas/library.ex`) | 5 | Next Read case study: `Book`, `Checkout`, `HoldRequest`, `Curation`, `RecommendationLog` — powers 6-factor ML recommendation ranker, PubSub reactive LiveViews, and Ash AI MCP tools |

Every domain uses `AshJsonApi.Domain` + `AshGraphql.Domain` + `AshAdmin.Domain`; `Billing`
additionally uses `AshTypescript.Rpc` for its `Subscription` resource, and `Library` exposes
read actions to `AshAi`'s MCP server. Full resource-by-resource route detail is in
`docs/claude/diataxis/reference/http-api-surface.md`.

Two more directories exist under `lib/xaas/` without a domain module of their own:
`autofde/` (`DemoPlannerReactor`, `StatusParser` — real Reactor-orchestrated planner demo, see
`reactor-autofde-planners-design.md`) and `telemetry/` (`OcelAshEmitter`, feeding the OCEL
process-intelligence pipeline in `wasm4pm-process-intelligence-research.md`).

## Routing: Multi-tier `/internal-api`, `/api`, `/mcp`, `/a2a`, and `/webhooks`

All real, from `lib/xaas_web/router.ex`. Every non-public route is gated by
`XaasWeb.Plugs.RequireInternalApiToken` — a real Bearer token check against
`INTERNAL_API_TOKEN`, fails closed (503) if the env var is unset.

1. **Public**: `GET /` (browser pipeline), `GET /next-read` (Next Read LiveView), and `POST /webhooks/stripe`
   (inbound Stripe receiver, deliberately *not* behind the internal-api token — Stripe is the
   caller and cannot supply it; authenticity is Stripe-signature verification inside
   `XaasWeb.StripeWebhookController` itself).
2. **Capability-liveness / health routes**: four hand-written GET routes
   under `/internal-api` — `capability_liveness_regressions`, `ocel_summary`,
   `prometheus/query`, `health` — registered *before* the catch-all forward below them because
   Phoenix `forward` matches every sub-path under its prefix and would otherwise shadow them.
3. **Production MCP server** (`/mcp`): `forward "/", AshAi.Mcp.Router` exposing read-only Library
   tools (`:list_books`, `:books_by_grade_band`, `:active_curations_for_grade`) to Claude Desktop,
   Zed, and Cursor.
4. **Agent-to-Agent server** (`/a2a`): `forward "/", A2A.Plug` with `XaasWeb.A2A.NextReadUserAgent`
   for multi-persona multi-turn simulations.
5. **Ontop SPARQL proxy**: `forward "/internal-api/sparql"` to
   `XaasWeb.OntopProxyPlug`, a real reverse proxy to the Ontop R2RML SPARQL endpoint.
6. **General internal API**: `forward "/internal-api"` to
   `XaasWeb.InternalApiRouter` (the generated `AshJsonApi.Router` for internal-facing
   resources), behind `:require_internal_api_token`.
7. **Customer-facing `/api`**: `forward "/api"` to
   `XaasWeb.ApiRouter`, behind `:require_internal_api_token` *and*
   `:resolve_org_actor`.

Dev-only routes (`LiveDashboard`, `AshAdmin` at `/admin`, the autofde-lab LiveView) are gated
behind `Application.compile_env(:kanban, :dev_routes)` and never mounted outside dev.

## Cross-cutting mechanisms

- **Actor/tenant resolution** — `XaasWeb.Plugs.ResolveOrgActor`
  (`lib/xaas_web/plugs/resolve_org_actor.ex`), mounted only on `/api`. It resolves an
  `X-Org-Id` header into the Ash actor/tenant, but is real path-aware: it only *enforces*
  resolution for the 4 non-global-multitenancy governance resources
  (`ApprovalDrFailover`/`ApprovalLegalHoldRelease`/`ApprovalDeploymentQuarantine`/
  `ApprovalBackupRetentionChange`); every other `/api` route passes through unaffected.
- **Ash-core multitenancy** — most multitenant resources (`Org`, `Provider`,
  `ApprovalProviderStatusChange`, most `Approval*` resources) use Ash's built-in
  `multitenancy` DSL directly rather than the `ResolveOrgActor` carve-out.
- **Atomic Invariant Concurrency** — inventory decrements (`Book.borrow_copy`), quota adjustments,
  and state changes use `change atomic_update` to prevent race conditions at the Postgres row level.
- **Reactor Actuation** — Consequential operations flow exclusively through `Xaas.Actuation` and
  Reactor steps, generating immutable audit receipts and supporting transactional rollback.
