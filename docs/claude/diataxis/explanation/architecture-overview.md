# Architecture Overview

This is the whole-system map for xaas: what the 13 Ash domains own, how the
`/internal-api` / `/api` / `/mcp` / `/a2a` / `/webhooks` routing splits requests, and how the
cross-cutting mechanisms — actor/tenant resolution, system-actor injection, audit trail,
webhooks, Reactor actuation, and the Ontop SPARQL bridge — compose on top of that resource
set. It links out to the narrower existing explainers rather than re-deriving their content;
read this first, then follow the links for depth on any one topic.

## The 13 Ash domains

Defined in `lib/xaas/*.ex` (`use Ash.Domain`), configured in `config/config.exs:13-27`,
resources counted directly from each domain's real `resources do ... end` block (92 total,
re-verified 2026-09-22):

| Domain | Module | Resources | What it owns |
|---|---|---|---|
| Accounts | `Xaas.Accounts` (`lib/xaas/accounts.ex`) | 5 | `User`, `Org`, `OrgMembership`, auth/PII data — `User`/`Token` deliberately unwired from `/api` (see below); `Org` is wired with real create/update routes |
| Billing | `Xaas.Billing` (`lib/xaas/billing.ex`) | 8 | Subscriptions and 6 maker-checker `Approval*` resources (pricing override, quota override, tier downgrade, SLA credit apply, patch SLA credit apply, invoice reconciliation approve) |
| Coupling | `Xaas.Coupling` (`lib/xaas/coupling.ex`) | 1 | Admission path for the formal proposal coupling engine: `CouplingRun` wires proposal sets into a box-constrained weighted-least-squares solver |
| Generation | `Xaas.Generation` (`lib/xaas/generation.ex`) | 1 | Deterministic generation closure `g(CanonicalGraph) -> Projection`; `ProjectionRecord` is the admission boundary forbidding `CanonicalGraph + ManualPatch` |
| Ledger | `Xaas.Ledger` (`lib/xaas/ledger.ex`) | 4 | Real financial ledger — `Balance`/`Account`/`Transfer` — deliberately unwired from `/api` (see below) |
| Marketplace | `Xaas.Marketplace` (`lib/xaas/marketplace.ex`) | 2 | `Provider` + its approval resource; multitenant via `actor_org_matches`/`actor_org_filter` checks; provider lifecycle mutation is fenced behind the receipted actuation path |
| Ocel | `Xaas.Ocel` (`lib/xaas/ocel.ex`) | 5 | Object-centric event log: typed events relate to sets of typed objects; object state is an append-only fold of deltas, never a mutated column |
| Operations | `Xaas.Operations` (`lib/xaas/operations.ex`) | 20 | `AuditLogEntry`, capability-liveness receipts, actuation intents/receipts, incidents, project measurement, incident/route-castle lifecycle, and the AutofdePlanner cache/catalog/candidate/match resources |
| Platform | `Xaas.Platform` (`lib/xaas/platform.ex`) | 7 | `Webhook` + `WebhookDelivery` (outbound HMAC dispatch), plus platform-level route/approval resources |
| Governance | `Xaas.Governance` (`lib/xaas/governance.ex`) | 28 | The largest domain: `FreezeWindow`, `AuditExportToken`, `PentestFinding`, `InternalApiToken`, and the bulk of the `Approval*` maker-checker surface, including the 4 non-global-multitenancy resources (`ApprovalDrFailover`, `ApprovalLegalHoldRelease`, `ApprovalDeploymentQuarantine`, `ApprovalBackupRetentionChange`) |
| Library | `Xaas.Library` (`lib/xaas/library.ex`) | 7 | Next Read case study: `Book`, `Checkout`, `HoldRequest`, `Curation`, `RecommendationLog`, `School`, `PersonaGrant` — powers 6-factor ML recommendation ranker, PubSub reactive LiveViews, Ash AI MCP tools, and the A2A persona agents |
| TemporalMemory | `Xaas.TemporalMemory` (`lib/xaas/temporal_memory.ex`) | 1 | Bitemporal process memory: `Observation` with retroactive-observation-safe admission, `as_of` query, deterministic replay verifier |
| Ultracode | `Xaas.Ultracode` (`lib/xaas/ultracode.ex`) | 3 | Run/Epoch/Receipt control plane for the autonomous execution fabric — runs, epochs, and the receipts that evidence them |

Extensions are no longer uniform: most domains use `AshJsonApi.Domain` +
`AshGraphql.Domain` + `AshAdmin.Domain`; `Accounts`, `Billing`, `Marketplace`, and
`Operations` additionally use `AshTypescript.Rpc`; `Governance` adds
`AshPaperTrail.Domain`; `Operations` adds its own `ProjectMeasure.Extension`; `Library`
exposes read actions to `AshAi`'s MCP server; `Coupling` and `Ocel` are Admin-only; and
`Generation`/`TemporalMemory` declare no domain extensions at all. Full extension and
route detail is in `docs/claude/diataxis/reference/ash-configuration.md` and
`docs/claude/diataxis/reference/http-api-surface.md`.

Beyond the domain modules, notable non-domain code under `lib/xaas/`: `ultracode/` (the
~45-module execution fabric: autonomic loop, sensing, campaigns, leases, audit, OCEL-gated
learning), `actuation/` (the Ash.Reactor control plane), `semantics/`
(public-ontology projection registry), `telemetry/` (OCEL 2.0 Ash-action emitter and
NDJSON egress), `zoe/` (event simulation), `sa2a/` (JSON-lines port bridge),
`workbench/` (GGen workbench client), `hddl/`, `planning/`, `checks/`, and `autofde/`.

## Routing: `/internal-api`, `/api`, `/mcp`, `/a2a`, `/webhooks`, and the execution fabric

All real, from `lib/xaas_web/router.ex` (re-verified 2026-09-22). Every non-public route is
gated by `XaasWeb.Plugs.RequireInternalApiToken` — a real Bearer token check against
`INTERNAL_API_TOKEN`, fails closed (503) if the env var is unset.

1. **Public**: `GET /` (browser pipeline), `GET /next-read` (Next Read LiveView), and `POST /webhooks/stripe`
   (inbound Stripe receiver, deliberately *not* behind the internal-api token — Stripe is the
   caller and cannot supply it; authenticity is Stripe-signature verification inside
   `XaasWeb.StripeWebhookController` itself).
2. **Plain-JSON controller routes under `/internal-api`**: capability liveness, OCEL
   summary, Prometheus query, health, the AshTypescript `rpc/run`/`rpc/validate` pair, the
   Ontop SPARQL proxy, and the execution-fabric endpoints (`execution/mcp` with its seven
   lease verbs, `execution/hooks/:event`, org-scoped `execution/runs`, and the receipt read
   path) — all registered *before* the catch-all forward below them because Phoenix
   `forward` matches every sub-path under its prefix and would otherwise shadow them.
3. **Execution fabric**: `POST /internal-api/execution/mcp` is the worker-facing MCP
   surface (`claim_next`, `heartbeat`, `admit_tool`, `record_provider_event`,
   `close_candidate`, `refuse`, `actuate`); `actuate` is the only provider-worker path into
   the admitted `Xaas.Actuation.run/4` DO kernel — every consequential worker action is
   lease-gated and receipted.
4. **Production MCP server** (`/mcp`): generated `XaasWeb.McpScope` forwarding to
   `AshAi.Mcp.Router`, exposing read-only Library tools (`:list_books`,
   `:books_by_grade_band`, `:active_curations_for_grade`) to MCP clients; one audit row is
   written per request by `XaasWeb.Plugs.AuditMcpToolCall`.
5. **Agent-to-Agent server** (`/a2a`): `POST /a2a/zoe-event` (ZOE event-simulation agent)
   and `POST /a2a/` (`XaasWeb.A2A.NextReadUserAgent`) for multi-persona multi-turn
   simulations.
6. **GGen workbench** (`/api/workbench/ggen`): CONSTRUCT-only forward of bounded bundles
   and argv to a private Fly worker — no shell or cloud actuation authority.
7. **General internal API**: `forward "/internal-api"` to
   `XaasWeb.InternalApiRouter` (the generated `AshJsonApi.Router` for internal-facing
   resources), behind `:require_internal_api_token`.
8. **Customer-facing `/api`**: `forward "/api"` to
   `XaasWeb.ApiRouter`, behind `:require_internal_api_token` *and*
   `:resolve_org_actor`.

Dev-only routes (`LiveDashboard`, `AshAdmin` at `/admin`, the autofde-lab LiveView) are gated
behind `Application.compile_env(:xaas, :dev_routes)` and never mounted outside dev.

## Cross-cutting mechanisms

- **Actor/tenant resolution** — `XaasWeb.Plugs.ResolveOrgActor`
  (`lib/xaas_web/plugs/resolve_org_actor.ex`), mounted only on `/api` (and a real no-op on
  `/mcp`, where its path allowlist never matches). It resolves an
  `X-Org-Id` header into the Ash actor/tenant, but is real path-aware: it only *enforces*
  resolution for the 4 non-global-multitenancy governance resources
  (`ApprovalDrFailover`/`ApprovalLegalHoldRelease`/`ApprovalDeploymentQuarantine`/
  `ApprovalBackupRetentionChange`); every other `/api` route passes through unaffected.
- **System-actor injection** — `XaasWeb.Plugs.SetInternalApiSystemActor` (XAAS-2602),
  mounted on both AshJsonApi forwards after the Bearer gate, supplies the real
  `Xaas.SystemAuthority` actor for the SERVICE-BOUNDARY resources whose mutation bypasses
  are guarded by `Xaas.Checks.SystemActor`; it never overrides an already-resolved org actor.
- **MCP call audit** — `XaasWeb.Plugs.AuditMcpToolCall` writes one
  `Xaas.Operations.AuditLogEntry` row per `/mcp` request so unscoped Library reads are
  observable (deliberately scoped to `/mcp` only).
- **Ash-core multitenancy** — most multitenant resources (`Org`, `Provider`,
  `ApprovalProviderStatusChange`, most `Approval*` resources) use Ash's built-in
  `multitenancy` DSL directly rather than the `ResolveOrgActor` carve-out.
- **Atomic Invariant Concurrency** — inventory decrements (`Book.borrow_copy`), quota adjustments,
  and state changes use `change atomic_update` to prevent race conditions at the Postgres row level.
- **Reactor Actuation** — Consequential operations flow exclusively through `Xaas.Actuation` and
  Reactor steps, generating immutable audit receipts and supporting transactional rollback.
  Worker-side consequential mutation additionally passes through the Ultracode lease kernel
  (`Xaas.Ultracode.Lease.actuate/2`) via the execution-fabric MCP `actuate` verb.
- **OCEL 2.0 telemetry** — every real Ash action emits an object-centric event correlated to
  its OpenTelemetry span (`lib/xaas/telemetry/`), rotation-bounded on disk and validated by
  the conformance court; the fabric's audit judges campaigns against it.
