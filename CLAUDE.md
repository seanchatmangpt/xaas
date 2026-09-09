# xaas — Project Instructions

Real BEAMOps-book-derived Elixir/Phoenix + Ash 3.x platform, with AWS chapters honestly substituted by `colima`+`kind` where documented. Current documentation is organized under `docs/claude/diataxis/`.

## Operating mode (explicit user direction, 2026-09-09)

**This is an exploration/implementation project, not a production system.** The point
of a work cycle (including the standing hourly Vision 2030 ERRC/FMEA/RCA swarm cycles
under `docs/vision/`) is throughput through real implementation — generating and
landing real code across many iterations — not gating every cycle behind a full green
`mix test` run. Concretely, this changes default behavior from the general Claude Code
verification discipline as follows, for this repo specifically:

- Don't block launching the next swarm/cycle on the previous one's tests passing.
  Report status honestly (compiled clean? tests ran? what failed?) but let work keep
  moving rather than treating a red suite as a hard stop.
- A cycle that lands real, disclosed, partially-verified work is a legitimate outcome —
  say plainly what's verified vs. still open (per the no-overclaiming discipline
  below), don't hold the commit hostage to full verification.
- Still apply real engineering judgment: don't skip verification because it's
  inconvenient, skip *gating on* verification because this repo's purpose is
  iteration speed. Real compile/test commands should still be run and their real
  output reported — the difference is whether a red/incomplete result blocks the next
  step (it doesn't, here) vs. whether it's honestly disclosed (it always is).
- This does not relax the Ash policy floor, API auth, or Chicago-style-testing
  sections below — those are about what the code *is*, not about whether every cycle
  waits for a clean test run before moving on.

## Read first

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

The disclosed pre-existing `Xaas.AwsRepo.FixtureAdapter` remains the one historical AWS-substitution exception.

### Claims require execution

"Compiles" requires a real compile run. "Works" requires a real product/test path. Source inspection, workflow presence, documentation, or a test name are not execution proof.

### Ash policy floor

New/touched resources keep deny-by-default policy behavior. A scoped read carve-out uses `bypass`; do not replace the floor with ambient allow-all behavior.

### API auth

`XaasWeb.Plugs.RequireInternalApiToken` gates `/internal-api` and `/api` using `INTERNAL_API_TOKEN` and fails closed when configuration is absent. Do not introduce an unauthenticated sibling route.

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
