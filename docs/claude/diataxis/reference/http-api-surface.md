# HTTP API surface

Canonical for XaaS v26.8.21. This reference describes mounted Phoenix transport, not hypothetical Ash actions.

## Authentication boundary

`KanbanWeb.Plugs.RequireInternalApiToken` protects all mounted `/internal-api` and `/api` routes, including the AshTypescript RPC adapter. The external Stripe webhook is deliberately outside that bearer-token boundary because Stripe is the caller; the webhook controller verifies Stripe's signature instead.

## Public routes

| Method | Path | Owner | Boundary |
| --- | --- | --- | --- |
| GET | `/` | `KanbanWeb.PageController` | browser |
| POST | `/webhooks/stripe` | `KanbanWeb.StripeWebhookController` | Stripe signature verification |

Development-only dashboard/mailbox/AshAdmin routes exist only when `:dev_routes` is enabled.

## Internal controller/proxy routes

These routes are declared before the `/internal-api` AshJsonApi catch-all so they cannot be shadowed by the forward.

| Method | Path | Owner |
| --- | --- | --- |
| GET | `/internal-api/capability_liveness_regressions` | `CapabilityRegressionsController` |
| GET | `/internal-api/ocel_summary` | `OcelSummaryController` |
| GET | `/internal-api/prometheus/query` | `PrometheusQueryController` |
| GET | `/internal-api/health` | `HealthController` |
| POST | `/internal-api/rpc/run` | `AshTypescriptRpcController` |
| POST | `/internal-api/rpc/validate` | `AshTypescriptRpcController` |
| forwarded | `/internal-api/sparql/*` | `KanbanWeb.OntopProxyPlug` |

The two RPC POST routes carry the currently read/observe-only AshTypescript action set. HTTP method alone does not grant mutation authority.

## Internal Ash JSON:API

`KanbanWeb.InternalApiRouter` forwards the `Xaas.Operations` domain under `/internal-api`. Only resource-declared JSON:API routes are eligible; mounting the domain does not manufacture routes.

## Customer-facing Ash JSON:API

`KanbanWeb.ApiRouter` mounts all **seven** configured domains under `/api`:

- `Xaas.Accounts`
- `Xaas.Billing`
- `Xaas.Governance`
- `Xaas.Ledger`
- `Xaas.Marketplace`
- `Xaas.Operations`
- `Xaas.Platform`

The `/api` pipeline adds both the internal bearer-token requirement and `KanbanWeb.Plugs.ResolveOrgActor`. The actor plug applies tenant/actor resolution only where a resource requires it; it is not a generic authorization substitute.

At the v26.8.21 baseline, 57 of 70 resources declare JSON:API routes. The ProjectMeasure addition is read-only and does not increase the mutation-route census.

### Project measurement

`Xaas.Operations.ProjectMeasure.Measurement` declares:

| Method | Path | Ash action | Semantics |
| --- | --- | --- | --- |
| GET | `/api/project_measurement/measure` | `:measure` | exact-subject GitHub Actions observation/admission |

The resource has no create/update/destroy actions, and the underlying GitHub sensor uses GET only.

## Deliberately unwired sensitive resources

Generic resource routing remains absent for:

- `Xaas.Ledger.Balance`
- `Xaas.Ledger.Account`
- `Xaas.Ledger.Transfer`
- `Xaas.Accounts.User`
- `Xaas.Accounts.Token`

Their sensitivity is not solved by mechanically creating a read route. A future exposure requires an explicit actor/tenant/access contract.

## AshTypescript RPC

The generated client and runtime router share these exact paths:

- `/internal-api/rpc/run`
- `/internal-api/rpc/validate`

The admitted RPC actions are:

- `list_accounts_orgs`
- `list_billing_subscriptions`
- `list_marketplace_providers`
- `measure_project`

`KanbanWeb.AshTypescriptRpcController` is an adapter only; action semantics and authorization remain in Ash.

## GraphQL

Ash GraphQL extensions describe query/action projections on resources/domains, including ProjectMeasure's `project_measure_json` query. No production GraphQL Phoenix route is claimed by this document unless one is actually mounted in `KanbanWeb.Router`; v26.8.21 does not infer transport exposure from the presence of GraphQL DSL metadata.

## Release verification

Transport documentation must stay synchronized with code. `mix xaas.release_audit` verifies canonical RPC endpoint agreement and stale topology claims. Exact-head CI additionally compiles the router and resource DSL, runs the ProjectMeasure route/projection falsifiers, and verifies generated AshTypescript drift.
