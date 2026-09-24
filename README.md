# XaaS

XaaS is an Elixir/Phoenix platform built around Ash resources. Ash resources are executable application models with public-ontology projections, and consequential mutation is fenced behind a synchronous `Ash.Reactor` actuation path with durable intent/receipt records and idempotent replay. Around that control plane, the repository also ships an autonomous execution fabric (leases, campaigns, receipted worker actuation), OCEL 2.0 telemetry egress, and a generated ZCode integration plugin.

Stack: Elixir ~> 1.18, Phoenix ~> 1.7, Ash ~> 3.0, PostgreSQL. Version: [`VERSION`](VERSION) (currently 26.9.17). Thirteen Ash domains are configured in `config/config.exs` (Accounts, Billing, Coupling, Generation, Governance, Ledger, Library, Marketplace, Ocel, Operations, Platform, TemporalMemory, Ultracode).

## Documentation

The canonical documentation entry point is [`docs/claude/diataxis/README.md`](docs/claude/diataxis/README.md). It separates:

- **Tutorials** — reproducible learning paths.
- **How-to guides** — procedures for concrete operational goals.
- **Reference** — exact contracts for APIs, configuration, auth, semantics, and refusals.
- **Explanation** — architecture, boundaries, rationale, and trade-offs.

Fabric-specific run documentation lives under [`docs/ultracode/`](docs/ultracode/eight-hour-run.md) (bounded eight-hour campaigns, multi-repo runs, wave receipts, standing-ledger hash chains). Historical evidence that no longer describes the supported system lives under [`docs/archive/`](docs/archive/).

## Current capability snapshot

Observed source and Chicago-style tests on `main@c2a7ea9fbefc9e45d89c30fad36afb3fee96fabd` establish these current contracts:

- `Xaas.Semantics.Registry` maps every `Xaas.Resource` projection onto admitted public namespaces and computes a deterministic SHA-256 projection identity.
- `Xaas.Actuation.run/4` requires a non-empty `:idempotency_key` and drives `admit -> do -> receipt` through `Xaas.Actuation.Reactor` synchronously inside the participating Ash data-layer transaction.
- `Xaas.Marketplace.Provider` exposes descriptive create/update behavior, but `:status` is not accepted by the public update action. The internal `:actuate_status` action is guarded by `Xaas.Actuation.Validations.ReactorContext` and has no JSON:API route.
- Exact-key replay returns the original receipt without repeating the mutation; reuse of the key for a different consequence is refused.

See [`reference/actuation-and-semantics.md`](docs/claude/diataxis/reference/actuation-and-semantics.md) for the precise contract.

## Ultracode execution fabric

`lib/xaas/ultracode/` is a Run/Epoch/Receipt control-plane domain for autonomous work:

- **Autonomic loop** — sense → plan → act → verify → repair → promote → learn ([`autonomic.ex`](lib/xaas/ultracode/autonomic.ex)), with profile-driven backlog sensing for registered repositories ([`sensing.ex`](lib/xaas/ultracode/sensing.ex)) and an OCEL-gated learning loop ([`learn.ex`](lib/xaas/ultracode/learn.ex)).
- **Campaigns** — bounded wave campaigns with a persisted budget law ([`campaign.ex`](lib/xaas/ultracode/campaign.ex)); campaign completion is judged by one audit ([`audit.ex`](lib/xaas/ultracode/audit.ex)) over terminality, head-verified evidence, and OCEL conformance.
- **Leases** — provider-pull claims over epochs ([`lease.ex`](lib/xaas/ultracode/lease.ex)); every consequential worker actuation carries a lease and seals a receipt.
- **Multi-repo registry** — clone paths, sensing profiles, and verifier suites per target repository ([`repos.ex`](lib/xaas/ultracode/repos.ex)).

Operate it through `mix xaas.ultracode.{start,status,stop,audit,learn,ocel_conformance,reconcile_runs,export_ocel,repos}`, `mix xaas.autonomic.{run,controls}`, and `mix xaas.semantic.crown`. Run procedures are documented under [`docs/ultracode/`](docs/ultracode/).

## Execution fabric internal API

All worker-facing routes sit behind the internal API token gate and fail closed when it is unset (`lib/xaas_web/controllers/execution_fabric_controller.ex`):

- `POST /internal-api/execution/mcp` — stateless MCP JSON-RPC with seven verbs: `claim_next`, `heartbeat`, `admit_tool`, `record_provider_event`, `close_candidate`, `refuse`, `actuate`.
- `POST /internal-api/execution/hooks/:event` — plain-JSON hook surface.
- `GET /internal-api/execution/epochs/:epoch_id/receipts` — receipt read path.
- `POST /internal-api/execution/runs` — org-scoped run submission.

`actuate` is the only way a provider worker crosses into the admitted `Xaas.Actuation.run/4` DO kernel.

## xaas-fabric ZCode plugin

`priv/zcode_plugin/` is a ggen project (`ontology.ttl` + templates) that renders the [`xaas-fabric`](priv/zcode_plugin/marketplace/xaas-fabric) ZCode plugin: the `xaas-execution` MCP server, a PreToolUse lease gate, a `/xaas` command, and the receipted worker doctrine (`claim → persist lease → admit_tool → close_candidate`). Projection drift is checked by [`test/xaas/zcode_plugin/projection_test.exs`](test/xaas/zcode_plugin/projection_test.exs).

## OCEL v2 telemetry

Every real Ash action emits an object-centric event log (OCEL 2.0) document correlated to the real OpenTelemetry span ([`telemetry/ocel_ash_emitter.ex`](lib/xaas/telemetry/ocel_ash_emitter.ex)). Events are written to rotation-bounded NDJSON validated by the conformance court ([`telemetry/ocel_ndjson.ex`](lib/xaas/telemetry/ocel_ndjson.ex)), optionally forwarded over the network ([`telemetry/ocel_forwarder.ex`](lib/xaas/telemetry/ocel_forwarder.ex)), and summarized at `GET /internal-api/ocel_summary`. The fabric runs batch OCEL conformance over every run a campaign names.

## Platform surface

- **Library / Next Read** — ML-ranked library recommendations over local embeddings; `/next-read` LiveView, read-only `/mcp` Ash AI server with per-call audit rows; case study in [`docs/case-studies/next-read/`](docs/case-studies/next-read/README.md).
- **A2A agents** — token-gated `/a2a` surface (ZOE event simulation, Next-Read persona agents).
- **SPARQL** — Ontop reverse proxy at `/internal-api/sparql`; live Postgres→RDF bridge.
- **Webhooks** — signature-verified `POST /webhooks/stripe`.
- **Workbench** — `POST /api/workbench/ggen` CONSTRUCT-only forward to a private Fly worker.
- **Bridges** — Castle PaaS bridge, supervised sa2a JSON-lines port bridge.
- **Dev-only** — AshAdmin at `/admin`, dev dashboards; never routed in production.

## Verification standing

This documentation does not promote source inspection to runtime proof. The repository doctrine requires real Postgres, real Ash actions, and real Reactor execution for ALIVE standing. The actuation tests in `test/xaas/actuation_test.exs` are the executable qualification surface; exact-head CI is used when a local runtime is unavailable.

## Development commands

The repository doctrine in [`CLAUDE.md`](CLAUDE.md) is authoritative for development and testing. Tests run against real Postgres via docker compose (`db` service, credentials under `secrets/.postgrespassword`); CLAUDE.md gives the exact environment export. Core qualification commands include:

```bash
mix compile --force
mix test
mix test --include stress
```

The narrow actuation falsifier is `mix test test/xaas/actuation_test.exs`. API routes under `/api` and `/internal-api` require the repository's internal API token policy; sensitive ledger/auth resources remain deliberately unwired unless an explicit access-control design is added.

## ZOE full-event simulation

`Xaas.Zoe.EventSimulation` consumes the authority-free `zoe-event-ops/v1` Planning Center observation contract and deterministically simulates a complete event: administration/rostering, registration/check-in, walk-ins, security capacity, reinforcement, incident routing, program start, incident resolution, attendance reconciliation, closing, and final reconciliation.

Every trace item is shaped as a SA2A capability observation with an explicit `OBSERVE | SELECT | CONSTRUCT` authority boundary and `do_authority: false`. Safety incidents route to both church event leadership and security management in the simulation, so the incident subject is never the router. The internal-token-gated A2A surface is `/a2a/zoe-event`.

The evidence ceiling is deliberately `SIMULATION_ONLY`. This document does not claim an `AshA2A.CommandBus` production DO, a provider write, deployment, or runtime standing promotion.
