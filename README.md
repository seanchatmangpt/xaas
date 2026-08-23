# XaaS

XaaS is an Elixir/Phoenix platform built around Ash resources. On the current `main` line, Ash resources are executable application models with public-ontology projections, and consequential provider lifecycle mutation is fenced behind a synchronous Ash.Reactor actuation path with durable intent/receipt records and idempotent replay.

## Documentation

The canonical documentation entry point is [`docs/claude/diataxis/README.md`](docs/claude/diataxis/README.md). It separates:

- **Tutorials** — reproducible learning paths.
- **How-to guides** — procedures for concrete operational goals.
- **Reference** — exact contracts for APIs, configuration, auth, semantics, and refusals.
- **Explanation** — architecture, boundaries, rationale, and trade-offs.

Historical evidence that no longer describes the supported system lives under [`docs/archive/`](docs/archive/).

## Current capability snapshot

Observed source and Chicago-style tests on `main@e856800a7341b617dcac345d769546387ecb2670` establish these current contracts:

- `Xaas.Semantics.Registry` maps every `Xaas.Resource` projection onto admitted public namespaces and computes a deterministic SHA-256 projection identity.
- `Xaas.Actuation.run/4` requires a non-empty `:idempotency_key` and drives `admit -> do -> receipt` through `Xaas.Actuation.Reactor` synchronously inside the participating Ash data-layer transaction.
- `Xaas.Marketplace.Provider` exposes descriptive create/update behavior, but `:status` is not accepted by the public update action. The internal `:actuate_status` action is guarded by `Xaas.Actuation.Validations.ReactorContext` and has no JSON:API route.
- Exact-key replay returns the original receipt without repeating the mutation; reuse of the key for a different consequence is refused.

See [`reference/actuation-and-semantics.md`](docs/claude/diataxis/reference/actuation-and-semantics.md) for the precise contract.

## Verification standing

This documentation does not promote source inspection to runtime proof. The repository doctrine requires real Postgres, real Ash actions, and real Reactor execution for ALIVE standing. The actuation tests in `test/xaas/actuation_test.exs` are the executable qualification surface; exact-head CI is used when a local runtime is unavailable.

## Development commands

The repository doctrine in [`CLAUDE.md`](CLAUDE.md) is authoritative for development and testing. Core qualification commands include:

```bash
mix compile --force
mix test
mix test --include stress
```

API routes under `/api` and `/internal-api` require the repository's internal API token policy; sensitive ledger/auth resources remain deliberately unwired unless an explicit access-control design is added.
