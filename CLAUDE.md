# xaas — Project Instructions

Real BEAMOps-book-derived Elixir/Phoenix + Ash 3.x platform, with AWS chapters honestly substituted by `colima`+`kind` where documented. Current documentation is organized under `docs/claude/diataxis/`.

## Read first

- `AGENTS.md` — Ash-ecosystem core-team usage rules (Zach Daniel et al.),
  hand-curated and compressed from the vendored `deps/*/usage-rules.md` /
  `deps/*/usage-rules/*.md` files (the raw `mix usage_rules.sync --all` output is a
  2500+ line dump — too dense to be a practical read-first doc). Update it by hand
  when a real gap surfaces; see the maintenance note at the top of the file for how
  to pull a full re-sync for comparison if needed.
- `docs/claude/diataxis/README.md` — canonical documentation map and authority rules.
- `docs/claude/diataxis/explanation/architecture-overview.md` — whole-system architecture.
- `docs/claude/diataxis/explanation/ontology-reactor-control-plane.md` — current public-ontology/Reactor actuation design.
- `docs/claude/diataxis/reference/actuation-and-semantics.md` — exact actuation, replay, receipt, and semantic-projection contracts.
- `docs/claude/diataxis/reference/ash-configuration.md` — current Ash configuration.
- `docs/claude/diataxis/reference/http-api-surface.md` — current HTTP exposure/auth surface.

Historical migration material lives in `docs/archive/` and is non-authoritative for current capability.

## Non-negotiable discipline

### Chicago-style testing

Use real Postgres via `Ecto.Adapters.SQL.Sandbox`, real Ash actions, and real HTTP requests via `ConnCase`. Do not add mocking libraries or owned-collaborator interaction fakes.

Before claiming the test tree is clean, run:

```bash
grep -rn "unittest.mock\|Mock(\|MagicMock\|patch(\|monkeypatch\|Mox\b\|:meck\|meck\." test/ lib/
```

The disclosed pre-existing `Kanban.AwsRepo.FixtureAdapter` remains the one historical AWS-substitution exception.

### Claims require execution

"Compiles" requires a real compile run. "Works" requires a real product/test path. Source inspection, workflow presence, documentation, or a test name are not execution proof.

### Ash policy floor

New/touched resources keep deny-by-default policy behavior. A scoped read carve-out uses `bypass`; do not replace the floor with ambient allow-all behavior.

### API auth

`KanbanWeb.Plugs.RequireInternalApiToken` gates `/internal-api` and `/api` using `INTERNAL_API_TOKEN` and fails closed when configuration is absent. Do not introduce an unauthenticated sibling route.

### Sensitive resources

`Xaas.Ledger.Balance`, `Xaas.Ledger.Account`, `Xaas.Ledger.Transfer`, `Xaas.Accounts.User`, and `Xaas.Accounts.Token` remain deliberate exposure decisions. Do not mechanically add routes for them.

### Consequential DO

Public semantic projection does not grant authority. Consequential mutations must remain behind the admitted Ash.Reactor control-plane path. For provider lifecycle state, do not expose or bypass `:actuate_status`; use `Xaas.Actuation.run/4` with a stable idempotency key and explicit authority context.

## Real commands

```bash
export DEV_DB_USERNAME=postgres DEV_DB_PASSWORD="$(cat secrets/.postgrespassword)" \
       DEV_DB_HOSTNAME=localhost DEV_DB_PORT=$(docker compose port db 5432 | cut -d: -f2)

mix compile --force
mix test
mix test --include stress

MIX_ENV=dev INTERNAL_API_TOKEN=<real-token> mix phx.server

ggen sync
```

For the current Reactor/semantic actuation boundary, the narrow falsifier is:

```bash
mix test test/xaas/actuation_test.exs
```

## Generated vs authoritative surfaces

Executable Ash resources/actions and repository-native generators are authoritative. Generated client/read projections must be regenerated through their lawful generator; do not hand-edit generated outputs unless repository doctrine explicitly makes them source surfaces.

## See also

- `docs/claude/diataxis/` — current Tutorial / How-to / Reference / Explanation docs.
- `docs/AWS-CHAPTERS-SUBSTITUTION.md` — current disclosed AWS substitution.
- `docs/archive/` — historical/non-authoritative plans and migration evidence.
