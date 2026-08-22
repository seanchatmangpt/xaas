# XaaS architecture overview

This document is the canonical architectural explanation for XaaS v26.8.21. For release acceptance criteria see `docs/PRD-v26.8.21.md`; for exact transport paths see `docs/claude/diataxis/reference/http-api-surface.md`.

## System shape

XaaS is an Ash 3.x application hosted by Phoenix. Business semantics live in Ash resources/domains. Spark provides compile-time DSL admission, Reactor owns workflow orchestration, AshPostgres owns persistent resource storage, Ash policies own authorization, and JSON:API / GraphQL / AshTypescript are projections of admitted Ash actions.

The layers are intentionally non-equivalent:

`transport -> Ash action/policy -> Reactor when orchestration is needed -> domain/storage/observation boundary -> receipt/evidence`

A transport route is not an authority grant. A Reactor is not a policy. A generated client is not a second implementation.

## Canonical Ash domain census

The configured domain graph contains **70** resources:

| Domain | Resources | Notable domain extensions |
| --- | ---: | --- |
| `Xaas.Accounts` | 5 | JSON:API, GraphQL, Admin, AshTypescript RPC |
| `Xaas.Billing` | 7 | JSON:API, GraphQL, Admin, AshTypescript RPC |
| `Xaas.Governance` | 27 | JSON:API, GraphQL, Admin |
| `Xaas.Ledger` | 4 | JSON:API, GraphQL, Admin |
| `Xaas.Marketplace` | 2 | JSON:API, GraphQL, Admin, AshTypescript RPC |
| `Xaas.Operations` | 18 | JSON:API, GraphQL, Admin, AshTypescript RPC, ProjectMeasure Spark extension |
| `Xaas.Platform` | 7 | JSON:API, GraphQL, Admin |
| **Total** | **70** | |

The release audit mechanically verifies this census, unique resource ownership, and registration of source modules using `Xaas.Resource`.

## AshTypescript

Four resources/actions are deliberately projected into the generated TypeScript RPC client in v26.8.21:

- `Xaas.Accounts.Org` -> `list_accounts_orgs`
- `Xaas.Billing.Subscription` -> `list_billing_subscriptions`
- `Xaas.Marketplace.Provider` -> `list_marketplace_providers`
- `Xaas.Operations.ProjectMeasure.Measurement` -> `measure_project`

The generated client targets `/internal-api/rpc/run` and `/internal-api/rpc/validate`. Phoenix mounts both routes behind `KanbanWeb.Plugs.RequireInternalApiToken`. The RPC controller delegates to `AshTypescript.Rpc`; it does not own business logic.

## Reactor workflows

The codebase has multiple real Reactor uses; v26.8.21 no longer describes Reactor as a single-demo capability.

`Xaas.Operations.DemoPlannerReactor` exercises the planner/orchestration path already present in Operations. Project measurement adds two related workflows:

- `Xaas.Operations.ProjectMeasure.Reactor` — live OBSERVE-only workflow: load Spark configuration, GET GitHub Actions observations, perform exact-subject admission/census, emit telemetry, return the receipt-bearing observation.
- `Xaas.Operations.ProjectMeasure.AdmissionReactor` — transport-free replay court over already captured observations.

Both keep orchestration separate from semantic admission and external authority.

## Exact-subject project measurement

`Xaas.Operations.ProjectMeasure.Measurement` is a stateless Ash resource. It has generic `:measure` and `:measure_json` actions and no create/update/destroy actions. Its exact commit SHA is an Ash NewType constrained to 40 hexadecimal characters.

The capability chain is:

`Spark DSL -> Spark verifier -> Ash typed action -> Reactor -> GET-only GitHub Actions sensor -> [since, until)+SHA census -> telemetry -> deterministic receipt/replay`

JSON:API exposes only GET for the measurement resource. GraphQL exposes the canonical JSON result as a query because an unconstrained Elixir map has no honest static GraphQL object shape. AshTypescript exposes the same action through the authenticated RPC adapter.

## HTTP topology

Phoenix owns three relevant transport classes:

1. Public web/webhook routes. Stripe remains public at the routing layer because Stripe is the caller; signature verification is the authenticity boundary.
2. Internal routes protected by `RequireInternalApiToken`, including health/observability, SPARQL proxying, AshTypescript RPC, and the internal Operations AshJsonApi router.
3. `/api`, also token-protected, forwarding all seven Ash domains through `KanbanWeb.ApiRouter`; per-org actor/tenant resolution is layered onto the subset that requires it.

At the v26.8.21 baseline, 57 of 70 resources declare JSON:API routes. Five sensitive resources remain deliberately unwired from generic customer-facing routes: `Xaas.Ledger.Balance`, `Xaas.Ledger.Account`, `Xaas.Ledger.Transfer`, `Xaas.Accounts.User`, and `Xaas.Accounts.Token`.

## Persistence and migration doctrine

AshPostgres resource snapshots describe current storage intent; timestamped Ecto migrations describe replayable schema history. A later generated migration may not recreate a table already created by an earlier migration. v26.8.21 repairs the pending-backlog migration accordingly and treats legacy plaintext token metadata as a fail-closed backfill precondition rather than data to discard.

## Release evidence

The repository-wide `mix xaas.release_audit` gate verifies version/runtime identity, domain/resource census, source registration, migration table-create uniqueness, tracked JSON, tracked shell syntax, Markdown links, stale architecture claims, canonical release docs, and RPC endpoint agreement.

CI additionally owns exact-head identity, warnings-as-errors compilation, database migration/tests, formatter standing, ProjectMeasure falsifiers, generated AshTypescript drift, Dialyzer, unused dependencies, and non-actuating container build qualification.

No green transport check or generated artifact by itself establishes whole-product `ALIVE`; standing is always scoped to the exact executed subject and completed verification boundary.
