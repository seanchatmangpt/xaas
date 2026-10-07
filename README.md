# XaaS

XaaS is an Elixir/Phoenix platform built around Ash resources. Ash resources are executable application models with public-ontology projections, and consequential mutation is fenced behind a synchronous `Ash.Reactor` actuation path with durable intent/receipt records and idempotent replay. Around that control plane, the repository also ships an autonomous execution fabric (leases, campaigns, receipted worker actuation), OCEL 2.0 telemetry egress, and a generated ZCode integration plugin.

Stack: Elixir ~> 1.18 (dev pinned via asdf `.tool-versions` to elixir 1.20.2-otp-28 / erlang 28.5.0.2), Phoenix ~> 1.7, Ash ~> 3.0, PostgreSQL. Version: [`VERSION`](VERSION). Nineteen Ash domains are configured in `config/config.exs` (`config/config.exs:13-33`, re-verified 2026-10-06) — Accounts, A2a, Billing, Conference, Coupling, Generation, Graphlaw, Governance, Igniter, Ledger, Library, Marketplace, Ocel, Operations, Platform, Security, TemporalMemory, Ultracode, Witness.

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
- **Self-digest kernel (CapitalCensus)** — Ultracode as a work subject of itself ([`capital_census/`](lib/xaas/ultracode/capital_census/)): the SelfDigest law ingests the wave loop's own NDJSON telemetry, clusters recurring gaps by topology, and emits provenance-gated self-work orders (`4a2e9d11`, `a9e3fa04`, `0a4e1a0a`; migration `20260927203551` adds the census/work-order tables inside the existing `Xaas.Ultracode` domain — work orders are the new work-subject surface). See [`docs/ultracode/self-digest.md`](docs/ultracode/self-digest.md).

Operate it through `mix xaas.ultracode.{start,status,stop,audit,learn,ocel_conformance,reconcile_runs,export_ocel,repos,tick_health}`, `mix xaas.autonomic.{run,controls}`, `mix xaas.autonomy.{qualify,audit,stress,export_ocel}` (`qualify --run <id>|--latest [N]` autonomy self-check over one Run: ALIVE / `PARTIAL_ALIVE (missing: ...)` / BLOCKED across five courts — edge resolution, replay determinism, coverage, origin authority, provider neutrality — via `Xaas.Ultracode.Recurrence.recurrence_edge/1`; `audit` = UAR/DCR=0 window audit, `stress` = injected-failure suite, `export_ocel` = OCEL 2.0 ndjson episode export), `mix xaas.semantic.crown`, `mix xaas.semantic.{materialize,receipt}`, `mix xaas.sjira.ard_court`, `mix xaas.fabric.redeploy`, and the goal-checkpoint court tasks `mix xaas.{stop_court,episode,machine_experience,replay}`. Two standalone validators: `mix xaas.ocel_validate <file.ocel.json>` runs the OCEL 2.0 conformance court over a log file as a CI-usable gate (exit 0 = pass, exit 1 = one line per violation; `--quiet` suppresses output), and `mix xaas.run_validate <file> [--run-id <uuid>]` judges an ultracode run's exported OCEL log (or, with a run id, validates that run directly) (`56a2810c`). `xaas.sjira.ard_court` exits 0 = ACCEPTED, `xaas.stop_court` exits 0 = STOP, `xaas.fabric.redeploy` is plan-only unless `--cut`, `xaas.autonomy.qualify` exits 0 when judged (ALIVE or PARTIAL_ALIVE) and non-zero only BLOCKED, matching `xaas.ultracode.audit`. `mix xaas.successor` is retired (v26.9.25): it prints `UNSUPPORTED(provider_capability)` (`compile_prose_retired`) and exits 69 without running. Run procedures are documented under [`docs/ultracode/`](docs/ultracode/).

## Execution fabric internal API

All worker-facing routes sit behind the internal API token gate and fail closed when it is unset (`lib/xaas_web/controllers/execution_fabric_controller.ex`):

- `POST /internal-api/execution/mcp` — stateless MCP JSON-RPC with eight verbs: `claim_next`, `heartbeat`, `admit_tool`, `record_provider_event`, `close_candidate`, `refuse`, `actuate`, `cancel_work` (cancels the leased work; the sealed receipt carries outcome `blocked` — cancellation, not subject failure). Bearer-authenticated with `INTERNAL_API_TOKEN`; observed serverInfo `xaas-ultracode-lease 1.0.0`.
- `POST /internal-api/execution/hooks/:event` — plain-JSON hook surface.
- `GET /internal-api/execution/epochs/:epoch_id/receipts` — receipt read path.
- `POST /internal-api/execution/runs` — org-scoped run submission.

The bounded runtime fabric (`lib/xaas_web/controllers/fabric_controller.ex`, protocol `xaas-fabric/1`) adds the `/internal-api/fabric` scope behind the same internal API token gate:

- `GET /internal-api/fabric/probe` — capabilities, protocol, and long-poll bound.
- `POST /internal-api/fabric/admit` — capability admit set (admitted / refused).
- `POST /internal-api/fabric/runs` — idempotent org-scoped submit keyed `fabric:<org>:<key>` under `pg_advisory_xact_lock` (201 new / 200 idempotent replay).
- `GET /internal-api/fabric/epochs/:epoch_id/receipts` — bounded long-poll (`wait_ms` ≤ 25000, `204` on timeout).
- `POST /internal-api/fabric/actuate` — always `403 REFUSED(authority_ceiling:actuate)`.

Fabric runs move through the pure state machine new → probed → admitted → submitted → executing → sealed → replayed.

`actuate` is the only way a provider worker crosses into the admitted `Xaas.Actuation.run/4` DO kernel.

## xaas-fabric ZCode plugin

`priv/zcode_plugin/` is a ggen project (`ontology.ttl` + templates) that renders the [`xaas-fabric`](priv/zcode_plugin/marketplace/xaas-fabric) ZCode plugin: the `xaas-execution` MCP server, a PreToolUse lease gate, a `/xaas` command, and the receipted worker doctrine (`claim → persist lease → admit_tool → close_candidate`). Projection drift is checked by [`test/xaas/zcode_plugin/projection_test.exs`](test/xaas/zcode_plugin/projection_test.exs). The `zcode_xaas_token` option is declared sensitive (masked in output); installed-plugin caches need a reinstall to pick the flag up.

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

## CS2 fleet contract

XaaS projects the canonical RFC-CS2-001 fleet contract as `cs2-fleet-contract/26.9.27` ([`lib/xaas/cs2/fleet_contract.ex`](lib/xaas/cs2/fleet_contract.ex), serialized artifact at [`priv/cs2/fleet-contract.json`](priv/cs2/fleet-contract.json)). The consuming path: `Xaas.CS2.SemanticJiraBridge` takes authority-free Semantic Jira projection candidates over the portable data shape (cross-repo contract via PR #87), `Xaas.CS2.AshA2ABridge.from_a2a/1` adapts CS2 packets into XaaS execution-package form, and `Xaas.CS2.EngineerWorkflow` packages the result for engineer-facing consumers. The whole `lib/xaas/cs2/` boundary is a representation boundary only: it packages admitted evidence and never creates runtime authority (no lease tokens, no consequential DO).

## Verification standing

This documentation does not promote source inspection to runtime proof. The repository doctrine requires real Postgres, real Ash actions, and real Reactor execution for ALIVE standing. The actuation tests in `test/xaas/actuation_test.exs` are the executable qualification surface; exact-head CI is used when a local runtime is unavailable.

## Development commands

The repository doctrine in [`CLAUDE.md`](CLAUDE.md) is authoritative for development and testing. Tests run against real local Postgres (brew `postgresql@14`, database `xaas_dev` on localhost:5432; `DEV_DB_*` env vars override — see `config/dev.exs`). Run all mix commands under the asdf-pinned toolchain (`.tool-versions`: elixir 1.20.2-otp-28 / erlang 28.5.0.2); a mixed-toolchain compile corrupts `_build` and can 500 a running server (observed 2026-09-26). Core qualification commands include:

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
