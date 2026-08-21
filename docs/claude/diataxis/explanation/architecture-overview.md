# Architecture Overview

This is the whole-system map for xaas: what the 7 Ash domains own, how the 3-tier
`/internal-api` (plus `/api` and `/webhooks`) routing splits requests, and how the
cross-cutting mechanisms — actor/tenant resolution, audit trail, webhooks, Reactor, and the
Ontop SPARQL bridge — compose on top of that resource set. It links out to the narrower
existing explainers rather than re-deriving their content; read this first, then follow the
links for depth on any one topic.

## The 7 Ash domains

Defined in `lib/xaas/*.ex` (`use Ash.Domain`), resources counted directly from each domain's
real `resources do ... end` block (69 total):

| Domain | Module | Resources | What it owns |
|---|---|---|---|
| Accounts | `Xaas.Accounts` (`lib/xaas/accounts.ex`) | 5 | `User`, `Org`, `OrgMembership`, auth/PII data — deliberately unwired from `/api` (see below) |
| Billing | `Xaas.Billing` (`lib/xaas/billing.ex`) | 7 | Subscriptions and 6 maker-checker `Approval*` resources (pricing override, quota override, tier downgrade, SLA credit apply, patch SLA credit apply, invoice reconciliation approve) |
| Ledger | `Xaas.Ledger` (`lib/xaas/ledger.ex`) | 4 | Real financial ledger — `Balance`/`Account`/`Transfer` — deliberately unwired from `/api` (see below) |
| Marketplace | `Xaas.Marketplace` (`lib/xaas/marketplace.ex`) | 2 | `Provider` + its approval resource; multitenant via `actor_org_matches`/`actor_org_filter` checks |
| Operations | `Xaas.Operations` (`lib/xaas/operations.ex`) | 17 | `AuditLogEntry`, capability-liveness receipts, incident/route-castle lifecycle, and the AutofdePlanner cache/catalog/candidate/match resources |
| Platform | `Xaas.Platform` (`lib/xaas/platform.ex`) | 7 | `Webhook` + `WebhookDelivery` (outbound HMAC dispatch), plus platform-level approvals |
| Governance | `Xaas.Governance` (`lib/xaas/governance.ex`) | 27 | The largest domain: `FreezeWindow`, `AuditExportToken`, and the bulk of the `Approval*` maker-checker surface, including the 4 non-global-multitenancy resources (`ApprovalDrFailover`, `ApprovalLegalHoldRelease`, `ApprovalDeploymentQuarantine`, `ApprovalBackupRetentionChange`) |

Every domain uses `AshJsonApi.Domain` + `AshGraphql.Domain` + `AshAdmin.Domain`; `Billing`
additionally uses `AshTypescript.Rpc` for its `Subscription` resource (see
`ash-typescript-adoption.md`). Full resource-by-resource route detail (which 56 of the 69 get
a real `json_api routes do` block, which 5 sensitive resources are deliberately unwired) is in
`docs/claude/diataxis/reference/http-api-surface.md` — this doc does not restate that table.
(Corrected 2026-08-21, thirteenth ERRC pass: real-recounted via `grep -rl "routes do" lib/xaas
--include="*.ex" | wc -l` → 56, not the stale 44 this line carried for 6 consecutive audit
passes; see `docs/claude/diataxis/explanation/errc-innovation-grid.md`.)

Two more directories exist under `lib/xaas/` without a domain module of their own:
`autofde/` (`DemoPlannerReactor`, `StatusParser` — real Reactor-orchestrated planner demo, see
`reactor-autofde-planners-design.md`) and `telemetry/` (`OcelAshEmitter`, feeding the OCEL
process-intelligence pipeline in `wasm4pm-process-intelligence-research.md`).

## Routing: 3-tier `/internal-api`, plus `/api` and `/webhooks`

All real, from `lib/kanban_web/router.ex:31-99`. Every non-public route is gated by
`KanbanWeb.Plugs.RequireInternalApiToken` — a real Bearer token check against
`INTERNAL_API_TOKEN`, fails closed (503) if the env var is unset (`router.ex:26-28`).

1. **Public** (`router.ex:31-46`): `GET /` (browser pipeline) and `POST /webhooks/stripe`
   (inbound Stripe receiver, deliberately *not* behind the internal-api token — Stripe is the
   caller and cannot supply it; authenticity is Stripe-signature verification inside
   `KanbanWeb.StripeWebhookController` itself).
2. **Capability-liveness / health routes** (`router.ex:57-64`): four hand-written GET routes
   under `/internal-api` — `capability_liveness_regressions`, `ocel_summary`,
   `prometheus/query`, `health` — registered *before* the catch-all forward below them because
   Phoenix `forward` matches every sub-path under its prefix and would otherwise shadow them
   (a real 404 confirmed this ordering requirement).
3. **Ontop SPARQL proxy** (`router.ex:73-77`): `forward "/internal-api/sparql"` to
   `KanbanWeb.OntopProxyPlug`, a real reverse proxy to the Ontop R2RML SPARQL endpoint — see
   `r2rml-ontop-prototype.md`. Also registered before the catch-all for the same shadowing
   reason.
4. **General internal API** (`router.ex:79-83`): `forward "/internal-api"` to
   `KanbanWeb.InternalApiRouter` (the generated `AshJsonApi.Router` for internal-facing
   resources), behind `:require_internal_api_token`.
5. **Customer-facing `/api`** (`router.ex:96-100`): `forward "/api"` to
   `KanbanWeb.ApiRouter`, behind `:require_internal_api_token` *and*
   `:resolve_org_actor` — see below.

Dev-only routes (`LiveDashboard`, `AshAdmin` at `/admin`, the autofde-lab LiveView) are gated
behind `Application.compile_env(:kanban, :dev_routes)` and never mounted outside dev.

## Cross-cutting mechanisms

- **Actor/tenant resolution** — `KanbanWeb.Plugs.ResolveOrgActor`
  (`lib/kanban_web/plugs/resolve_org_actor.ex`), mounted only on `/api`. It resolves an
  `X-Org-Id` header into the Ash actor/tenant, but is real path-aware: it only *enforces*
  resolution for the 4 non-global-multitenancy governance resources
  (`ApprovalDrFailover`/`ApprovalLegalHoldRelease`/`ApprovalDeploymentQuarantine`/
  `ApprovalBackupRetentionChange`); every other `/api` route passes through unaffected. See
  that plug's own moduledoc for the full disclosed design.
- **Ash-core multitenancy** — most multitenant resources (`Org`, `Provider`,
  `ApprovalProviderStatusChange`, most `Approval*` resources) use Ash's built-in
  `multitenancy` DSL directly rather than the `ResolveOrgActor` carve-out; grep
  `multitenancy` under `lib/xaas/` for the current list.
- **AshIam** — mounted on `User`, `Org`, `OrgMembership`, `Provider`
  (`lib/xaas/accounts/{user,org_membership}.ex`, `lib/xaas/marketplace/provider.ex`), but
  real-restricted to `:read` actions only. See `ashiam-create-update-limitation.md` for why
  create/update went through hand-written actions instead.
- **AshPaperTrail** — 6 of 69 resources have real version history:
  `Governance.{ApprovalFreezeOverride, ApprovalBackupRetentionChange,
  ApprovalDeploymentQuarantine, ApprovalLegalHoldRelease, ApprovalDrFailover, FreezeWindow}`.
  No resource outside `Governance` has it yet — in particular
  `Xaas.Operations.AuditLogEntry` does not (a real, still-open gap; see
  `errc-innovation-grid.md`'s sixth-pass carried-forward findings).
- **`AuditLogEntry`** — `lib/xaas/operations/audit_log_entry.ex`, written via
  `Xaas.Governance.Changes.WriteAuditLogEntry`
  (`lib/xaas/governance/changes/write_audit_log_entry.ex`); a separate, narrower mechanism
  from AshPaperTrail — this is an explicit application-level audit event log, not a
  resource-attribute version history.
- **Webhooks, both directions**:
  - *Inbound*: `POST /webhooks/stripe` → `KanbanWeb.StripeWebhookController` (public, see
    routing tier 1 above).
  - *Outbound*: `Xaas.Platform.Webhook` + `Xaas.Platform.WebhookDelivery`
    (`lib/xaas/platform/{webhook,webhook_delivery}.ex`), dispatched via
    `Xaas.Platform.Changes.DeliverWebhook` with real HMAC signing, enqueued from governance
    approval actions via `Xaas.Governance.Changes.EnqueueWebhookDeliveries`.
- **Reactor** — `Xaas.Autofde.DemoPlannerReactor` (`lib/xaas/autofde/demo_planner_reactor.ex`)
  is the one real `Reactor`-orchestrated workflow in the codebase today; see
  `reactor-autofde-planners-design.md` for the full design and the standing "single demo
  planner, not yet generalized" scope note.
- **Ontop / R2RML SPARQL bridge** — reverse-proxied at `/internal-api/sparql` (routing tier 3
  above); full mapping and prototype status in `r2rml-ontop-prototype.md`.

## Deliberately unwired resources

`Xaas.Ledger.{Balance, Account, Transfer}` (real financial data) and
`Xaas.Accounts.{User, Token}` (real auth/PII) have no `json_api routes do` block and are not
reachable via `/api` or `/internal-api`. This is a standing, disclosed decision — see
`CLAUDE.md`'s "Never blindly wire routes on sensitive resources" and
`docs/claude/diataxis/reference/http-api-surface.md` for the current, real route inventory.
Adding routes to any of these needs a real, explicit access-control design first, not
mechanical generation.

## See Also

- `docs/claude/diataxis/reference/ash-configuration.md` — real, current `config/*.exs` facts
- `docs/claude/diataxis/reference/http-api-surface.md` — full 69-resource route inventory
- `docs/ASH-MIGRATION-PLAN.md` — 7-phase migration history + standing deferred decisions
- `docs/claude/diataxis/explanation/ashiam-create-update-limitation.md`
- `docs/claude/diataxis/explanation/r2rml-ontop-prototype.md`
- `docs/claude/diataxis/explanation/reactor-autofde-planners-design.md`
- `docs/claude/diataxis/explanation/ash-typescript-adoption.md`
- `docs/claude/diataxis/explanation/wasm4pm-process-intelligence-research.md`
- `docs/claude/diataxis/explanation/security-and-testing-decisions.md`
- `docs/claude/diataxis/explanation/errc-innovation-grid.md` — sixth-pass ERRC grid that
  identified this doc as the highest-value CREATE item
