# Ash Configuration Reference

Dry, factual enumeration of xaas's real Ash configuration surface: config keys, domains,
extensions, custom types, and environment variables. This is a reference (Diataxis) doc — for
why these choices were made, see the companion Explanation doc; for how to add a resource, see
the How-to guide.

## Compile-time config (`config/config.exs`)

### `:kanban` app config

| Key | Value |
|---|---|
| `ecto_repos` | `[Kanban.Repo, Xaas.Repo]` |
| `ash_domains` | `[Xaas.Accounts, Xaas.Billing, Xaas.Governance, Xaas.Ledger, Xaas.Operations, Xaas.Platform]` |
| `ash_authentication` | `[return_error_on_invalid_magic_link_token?: true]` |
| `base_resources` | `[Xaas.Resource]` |

`Xaas.Resource` (`lib/xaas/resource.ex`) is a thin `defmacro __using__` wrapper around
`use Ash.Resource, unquote(opts)` — every real `Xaas.*` resource module does
`use Xaas.Resource, otp_app: :kanban, domain: ..., data_layer: AshPostgres.DataLayer, ...`.

### `:ash` global config

| Key | Value |
|---|---|
| `tracer` | `[OpentelemetryAsh]` |
| `allow_forbidden_field_for_relationships_by_default` | `true` |
| `include_embedded_source_by_default?` | `false` |
| `show_keysets_for_all_actions?` | `false` |
| `default_page_type` | `:keyset` |
| `policies` | `[no_filter_static_forbidden_reads?: false]` |
| `keep_read_action_loads_when_loading?` | `false` |
| `default_actions_require_atomic?` | `true` |
| `read_action_after_action_hooks_in_order?` | `true` |
| `bulk_actions_default_to_errors?` | `true` |
| `transaction_rollback_on_error?` | `true` |
| `redact_sensitive_values_in_errors?` | `true` |
| `many_to_many_destroy_destination_on_match?` | `true` |
| `known_types` | `[AshPostgres.Timestamptz, AshPostgres.TimestamptzUsec, AshMoney.Types.Money]` |
| `custom_types` | see [Custom types](#custom-types-registered-under-ash-config) below |

`config :ash, :tracer, [OpentelemetryAsh]` is the actual line that makes
`OpentelemetryAsh.start_span/2` get called by Ash — before this line was added,
`opentelemetry_ash` was a listed dep but never wired as Ash's tracer (dead code, confirmed via
grep of `config :ash, :tracer` returning no matches before this line existed).

### Custom types registered under `:ash` config

```elixir
custom_types: [
  money: AshMoney.Types.Money,
  capability_class: Xaas.Governance.Types.CapabilityClass,
  interface: Xaas.Governance.Types.Interface
]
```

| Short type code | Module | Definition |
|---|---|---|
| `:money` | `AshMoney.Types.Money` | (from `ash_money` dep) |
| `:capability_class` | `Xaas.Governance.Types.CapabilityClass` | `lib/xaas/governance/types/capability_class.ex` — `use Ash.Type.Enum, values: [:observe, :select, :construct, :do]` |
| `:interface` | `Xaas.Governance.Types.Interface` | `lib/xaas/governance/types/interface.ex` — `use Ash.Type.Enum, values: [:cli, :api, :mcp, :a2a]` |

These short codes resolve only because of this registration — resource files reference `:money`,
`:capability_class`, `:interface` directly as attribute types, and omitting this block produces a
real compile error (`":money is not a valid type"`).

### `:ash_graphql` config

| Key | Value |
|---|---|
| `authorize_update_destroy_with_error?` | `true` |

### `:ash_json_api` config

| Key | Value |
|---|---|
| `show_public_calculations_when_loaded?` | `false` |
| `authorize_update_destroy_with_error?` | `true` |

### `:ash_oban` config

| Key | Value |
|---|---|
| `pro?` | `false` |

### `:kanban, Oban` config

| Key | Value |
|---|---|
| `engine` | `Oban.Engines.Basic` |
| `notifier` | `Oban.Notifiers.Postgres` |
| `queues` | `[default: 10]` |
| `repo` | `Xaas.Repo` |
| `plugins` | `[{Oban.Plugins.Cron, []}]` |

## The 6 real Ash domains and their extensions

All 6 domains live directly under `lib/xaas/*.ex` (one file per domain), each
`use Ash.Domain, otp_app: :kanban, extensions: [...]`, each with `admin do show? true end`.

| Domain module | File | Extensions | Resource count |
|---|---|---|---|
| `Xaas.Accounts` | `lib/xaas/accounts.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 3 |
| `Xaas.Billing` | `lib/xaas/billing.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 6 |
| `Xaas.Governance` | `lib/xaas/governance.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshPaperTrail.Domain`, `AshAdmin.Domain` | 24 |
| `Xaas.Ledger` | `lib/xaas/ledger.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 4 |
| `Xaas.Operations` | `lib/xaas/operations.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 10 |
| `Xaas.Platform` | `lib/xaas/platform.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 5 |

`Xaas.Governance` is the only domain with `AshPaperTrail.Domain` and a `paper_trail do
include_versions? true end` block, and it is the largest domain (24 resources).

Every domain also declares `admin do show? true end` — this is the root-cause fix for
AshAdmin's real "resource has no actions" / not-shown-in-nav failure mode; without it, resources
in that domain do not appear in the AshAdmin UI even though the domain is passed to
`AshAdmin.Router`'s `domains:` list. `Xaas.Operations.CapabilityLivenessReceipt` (the MAPE-K
receipt resource) lives under `Xaas.Operations`.

## Resource-level extension surface (`mix.exs` real deps)

The real `deps/0` list in `mix.exs` (Ash core + extensions actually used by the 89 ported
`Xaas.*` resource modules, confirmed via grep of `extensions:`/`use` across those files):

| Dep | Version req | Purpose |
|---|---|---|
| `ash` | `~> 3.0` | Core framework |
| `ash_postgres` | `~> 2.0` | Postgres data layer |
| `opentelemetry_ash` | `~> 0.1` | Tracer (see `config :ash, :tracer`) |
| `ash_onetime` | `~> 1.0` | One-time-use nonce protection (used by `Xaas.Accounts.Token.RevokeVerifier`) |
| `ash_iam` | `~> 2.0` | IAM/identity resource support |
| `hammer` | `~> 7.0` | Rate-limiter backend |
| `ash_rate_limiter` | `~> 2.0` | Rate limiting extension |
| `cloak` | `~> 1.0` | Field-level encryption engine |
| `ash_cloak` | `~> 0.3` | Ash integration for Cloak (`Xaas.Accounts.Token`'s `cloak do ... end`) |
| `ex_money_sql` | `~> 2.0` | Money Ecto type |
| `ash_money` | `~> 0.2` | Ash integration for Money (`:money` custom type) |
| `ash_double_entry` | `~> 1.0` | Double-entry ledger support (`Xaas.Ledger`) |
| `ash_archival` | `~> 2.0` | Soft-delete/archival |
| `ash_events` | `~> 0.7` | Event sourcing |
| `ash_paper_trail` | `~> 0.6` | Versioning (`Xaas.Governance`) |
| `ash_state_machine` | `~> 0.2` | State machine actions |
| `oban` | `~> 2.0` | Background job engine |
| `ash_oban` | `~> 0.8` | Ash-Oban trigger integration |
| `ash_admin` | `~> 1.3` | Admin UI (`AshAdmin.Router`/`AshAdmin.Domain`) |
| `ash_graphql` | `~> 1.0` | GraphQL API extension |
| `open_api_spex` | `~> 3.0` | OpenAPI spec support (used with `ash_json_api`) |
| `ash_json_api` | `~> 1.0` | JSON:API extension |
| `bcrypt_elixir` | `~> 3.0` | Password hashing |
| `ash_authentication` | `~> 4.0` | Auth strategies (`AshAuthentication.Sender`, `TokenResource`) |
| `picosat_elixir` | `~> 0.2` | SAT solver (Ash policy engine dependency) |

Deliberately **not** used, with the real reason recorded in `mix.exs` comments:

| Dep considered | Status | Real reason |
|---|---|---|
| `ash_ai` | Dropped | Transitive dep `req_llm` fails to compile against resolved `finch` version (`%Finch.Pool{}`/pool_tag mismatch); zero real resource files reference `AshAi` |
| `ash_authentication_phoenix` | Dropped | Forces `phoenix_html ~> 4.0`, a resolver conflict; zero resource files reference it — only the core `ash_authentication` lib (`AshAuthentication.Sender`) is used |

## Custom types (Governance-owned enums)

| Module | File | Definition |
|---|---|---|
| `Xaas.Governance.Types.CapabilityClass` | `lib/xaas/governance/types/capability_class.ex` | `Ash.Type.Enum, values: [:observe, :select, :construct, :do]` |
| `Xaas.Governance.Types.Interface` | `lib/xaas/governance/types/interface.ex` | `Ash.Type.Enum, values: [:cli, :api, :mcp, :a2a]` |

Both are registered in `config :ash, :custom_types` (see above) as `:capability_class` and
`:interface`.

## Router / API surface wiring

| Router module | File | Mounts | Prefix |
|---|---|---|---|
| `KanbanWeb.ApiRouter` | `lib/kanban_web/api_router.ex` | `AshJsonApi.Router` over all 6 domains | `/api` |
| `KanbanWeb.InternalApiRouter` | `lib/kanban_web/internal_api_router.ex` | `AshJsonApi.Router` over `[Xaas.Operations]` only | `/internal-api` |

Both routers only ever serve routes a resource has explicitly declared via its own
`json_api do routes do ... end end` block — mounting a domain does not itself expose anything.
`KanbanWeb.ApiRouter`'s moduledoc records that 44 of 49 resources have mechanically-added
read-only (`get`/`index` on `:read`) routes; `Xaas.Ledger.Balance`/`Account`/`Transfer` and
`Xaas.Accounts.User`/`Token` are deliberately excluded (no routes declared).

Both `/api` and `/internal-api` scopes in `lib/kanban_web/router.ex` are gated by the
`:require_internal_api_token` pipeline (`plug KanbanWeb.Plugs.RequireInternalApiToken`,
`lib/kanban_web/plugs/require_internal_api_token.ex`) before reaching either router. This same
gate also protects the plain-JSON `/internal-api/capability_liveness_regressions` and
`/internal-api/ocel_summary` routes (which must be registered before the catch-all
`forward "/internal-api"`, since Phoenix `forward` matches every sub-path under its prefix).

`AshAdmin.Router`'s `ash_admin("/")` is mounted at `/admin`, guarded by the same
`Application.compile_env(:kanban, :dev_routes)` flag as `live_dashboard "/dashboard"` — dev-only,
no auth added (see `lib/kanban_web/router.ex` lines ~81-90).

## Environment variables read by this app

| Env var | Read in | Default (dev/test) | Purpose |
|---|---|---|---|
| `DEV_DB_USERNAME` | `config/dev.exs`, `config/test.exs` | `"postgres"` | Postgres username for `Kanban.Repo` and `Xaas.Repo` |
| `DEV_DB_PASSWORD` | `config/dev.exs`, `config/test.exs` | `"postgres"` | Postgres password for both repos |
| `DEV_DB_HOSTNAME` | `config/dev.exs`, `config/test.exs` | `"localhost"` | Postgres host for both repos |
| `DEV_DB_PORT` | `config/dev.exs`, `config/test.exs` | `"5432"` | Postgres port for both repos |
| `DEV_ONETIME_REVOKE_KEY` | `config/dev.exs` | `"dev-only-onetime-revoke-key"` | HMAC key for `Xaas.Accounts.Token.RevokeVerifier`'s `ash_onetime` nonce protection on `:revoke_token`, dev env |
| `MIX_TEST_PARTITION` | `config/test.exs` | (unset) | Suffix on `kanban_test<N>` database name for CI test partitioning |
| `INTERNAL_API_TOKEN` | `lib/kanban_web/plugs/require_internal_api_token.ex` | none — unset means fail-closed 503 | Bearer token required on `Authorization: Bearer <token>` for `/api` and `/internal-api`; compared with `Plug.Crypto.secure_compare/2` |
| `CLOAK_KEY` | `lib/xaas/vault.ex` | `"4T4/f5PYK0d489Do8sNU8VNJHKD/1XVOLXyzHUlIkQY="` (dev-only placeholder, publicly committed) | Base64-encoded 32-byte AES-GCM key for `Xaas.Vault` (`Cloak.Vault`), used by `AshCloak` to encrypt `Xaas.Accounts.Token`'s `:extra_data` attribute |
| `PHX_SERVER` | `config/runtime.exs` | (unset) | If set, forces `KanbanWeb.Endpoint` `server: true` under a release |
| `USE_AWS_FIXTURE_ADAPTER` | `config/runtime.exs` | `"false"` | If `"true"`, configures `Kanban.AwsRepo` to use `Kanban.AwsRepo.FixtureAdapter` |
| `DATABASE_URL` | `config/runtime.exs` (`:prod` only) | none — raises if unset | Ecto connection URL for `Kanban.Repo` and `Xaas.Repo` in production |
| `ECTO_IPV6` | `config/runtime.exs` (`:prod` only) | (unset) | If `"true"`/`"1"`, adds `:inet6` to repo `socket_options` |
| `ONETIME_REVOKE_KEY` | `config/runtime.exs` (`:prod` only) | none — raises if unset | Production value of the same HMAC key as `DEV_ONETIME_REVOKE_KEY` |
| `POOL_SIZE` | `config/runtime.exs` (`:prod` only) | `"10"` | Ecto pool size for both repos in production |
| `SECRET_KEY_BASE` | `config/runtime.exs` (`:prod` only) | none — raises if unset | Phoenix endpoint secret key base |
| `PHX_HOST` | `config/runtime.exs` (`:prod` only) | `"example.com"` | Production endpoint host |
| `PORT` | `config/dev.exs`, `config/runtime.exs` (`:prod`) | `"4000"` | HTTP port |

## Repos

| Repo module | Config location | Database (dev/test) | Notes |
|---|---|---|---|
| `Kanban.Repo` | `config/dev.exs`, `config/test.exs`, `config/runtime.exs` | `kanban_dev` / `kanban_test<partition>` | Original Phoenix/Kanban repo |
| `Xaas.Repo` | `config/dev.exs`, `config/test.exs`, `config/runtime.exs` | `kanban_dev` / `kanban_test<partition>` (same database, separate `Ecto.Repo`/OTP child) | All 89 ported `Xaas.Resource` modules declare `postgres do repo Xaas.Repo end` directly |

In test, both repos use `pool: Ecto.Adapters.SQL.Sandbox` with `pool_size: 20`.

## See Also

- `config/config.exs`, `config/dev.exs`, `config/test.exs`, `config/runtime.exs`, `mix.exs` — the
  real source files this reference was generated from
- `lib/xaas/resource.ex` — the `Xaas.Resource` base module every domain resource uses
- `lib/xaas/vault.ex`, `lib/xaas/accounts/token.ex` — real `AshCloak`/`Cloak.Vault` wiring
- `lib/xaas/governance/types/capability_class.ex`, `lib/xaas/governance/types/interface.ex` —
  the two custom Ash enum types
- `lib/kanban_web/router.ex`, `lib/kanban_web/api_router.ex`,
  `lib/kanban_web/internal_api_router.ex`, `lib/kanban_web/plugs/require_internal_api_token.ex` —
  real router/auth wiring
- `docs/ASH-MIGRATION-PLAN.md` — the real migration plan this config surface was ported under
