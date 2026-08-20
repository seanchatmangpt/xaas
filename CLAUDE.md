# xaas — Project Instructions

Real BEAMOps-book-derived Elixir/Phoenix + Ash 3.x platform, AWS chapters honestly
substituted with `colima`+`kind` (see `docs/AWS-CHAPTERS-SUBSTITUTION.md`). This file is the
entry point; full docs live in `docs/claude/diataxis/` (Diataxis: tutorials, how-to,
reference, explanation).

## Read first

- `docs/ASH-MIGRATION-PLAN.md` — the real 7-phase migration history + the standing,
  explicitly-deferred decisions (Phase 5: customer-facing mutation API surface,
  per-resource authorization policies). Deferred means genuinely undecided, not done —
  check there before assuming a capability exists.
- `docs/claude/diataxis/reference/ash-configuration.md` — real, current `config/*.exs`
  facts (domains, extensions, env vars this app reads).
- `docs/claude/diataxis/reference/http-api-surface.md` — real, current HTTP routes: which
  of the 49 Ash resources have a real `json_api routes do` block, which 5 are deliberately
  unwired (financial ledger + auth/PII data), and the real auth requirement.

## Non-negotiable discipline for this project

### Chicago-style testing, no exceptions
Real Postgres via `Ecto.Adapters.SQL.Sandbox`, real Ash actions, real HTTP requests via
`ConnCase`. **Zero mocking libraries** — no `Mox`, no hand-rolled interaction-verifying
fakes of collaborators this codebase owns. Before claiming tests are clean, run for real:

```bash
grep -rn "unittest.mock\|Mock(\|MagicMock\|patch(\|monkeypatch\|Mox\b\|:meck\|meck\." test/ lib/
```

Zero matches is the bar. A prior clean run does not certify code changed since — re-run it.
The one pre-existing exception is `Kanban.AwsRepo.FixtureAdapter` (the book's own original
code, real AWS-substitution, disclosed in `docs/AWS-CHAPTERS-SUBSTITUTION.md`) — do not add
a second one without the same disclosure discipline.

### Every claim needs a real run, not a description
"Compiles" means a real `mix compile --force` you just ran, pasted output attached to the
commit message. "Works" means a real `curl`/`mix test`/booted `mix phx.server` you just
exercised. This project has a real history of adversarial review catching overclaimed work
(see `docs/claude/diataxis/explanation/security-and-testing-decisions.md`) — assume the next
reviewer will re-run everything you claimed, because they will.

### Ash policy floor: deny-by-default
New/touched resources get:

```elixir
policies do
  policy always() do
    forbid_if always()
  end
end
```

Never relax to allow-all. A real, scoped read carve-out uses `bypass`, not `policy` — a
plain `policy action_type(:read) do authorize_if always() end` still ANDs against the
catch-all `forbid_if always()` (Ash's multi-policy semantics: every *matching* policy must
authorize) and silently filters everything out. This was a real bug found by adversarial
review this session — see the how-to guide for the correct pattern.

### Every internal-api / api route needs real auth
`KanbanWeb.Plugs.RequireInternalApiToken` gates `/internal-api` and `/api` — real Bearer
token against `INTERNAL_API_TOKEN`, fails closed (503) if unset. A route with zero auth
plug was a real, adversarial-review-caught gap once already; don't reintroduce it.

### Never blindly wire routes on sensitive resources
`Xaas.Ledger.Balance`/`Account`/`Transfer` (real financial data) and
`Xaas.Accounts.User`/`Token` (real auth/PII) are deliberately unwired. Adding a route to any
of them needs a real, explicit access-control design first — not mechanical generation.

## Real commands that work

```bash
# Env vars every mix/curl session against the real docker-compose Postgres needs:
export DEV_DB_USERNAME=postgres DEV_DB_PASSWORD="$(cat secrets/.postgrespassword)" \
       DEV_DB_HOSTNAME=localhost DEV_DB_PORT=$(docker compose port db 5432 | cut -d: -f2)

mix compile --force        # real, clean compile check
mix test                   # real Chicago-style suite (stress tests excluded by default)
mix test --include stress  # include the real 50-concurrent-task stress test

# Boot the real dev server (needs INTERNAL_API_TOKEN for /api and /internal-api to work):
MIX_ENV=dev INTERNAL_API_TOKEN=<real-token> mix phx.server

# ggen -> real Igniter-backed Ash resource codegen (see the how-to guide):
ggen sync
```

## See Also

- `docs/claude/diataxis/` — full Tutorial/How-to/Reference/Explanation docs
- `docs/ASH-MIGRATION-PLAN.md` — migration history + standing deferred decisions
- `docs/AWS-CHAPTERS-SUBSTITUTION.md` — the real, disclosed AWS-chapter gap
- `~/.claude/rules/testing-chicago-style.md` — the global testing discipline this project
  follows exactly (no project-specific relaxation)
