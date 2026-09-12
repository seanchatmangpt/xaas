# Ash Configuration Reference

Dry, factual enumeration of xaas's real Ash configuration surface: config keys, domains,
extensions, custom types, and environment variables. This is a reference (Diataxis) doc — for
why these choices were made, see the companion Explanation doc (`explanation/ash-is-the-xaas.md`).

## Compile-time config (`config/config.exs`)

### `:kanban` / `:xaas` app config

| Key | Value |
|---|---|
| `ecto_repos` | `[Xaas.LegacyRepo, Xaas.Repo]` |
| `ash_domains` | `[Xaas.Accounts, Xaas.Billing, Xaas.Governance, Xaas.Ledger, Xaas.Operations, Xaas.Platform, Xaas.Marketplace, Xaas.Library]` |
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

## The 8 real Ash domains and their extensions

All 8 domains live directly under `lib/xaas/*.ex` (one file per domain), each
`use Ash.Domain, otp_app: :kanban, extensions: [...]`, each with `admin do show? true end`.

| Domain module | File | Extensions | Resource count |
|---|---|---|---|
| `Xaas.Accounts` | `lib/xaas/accounts.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 5 |
| `Xaas.Billing` | `lib/xaas/billing.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain`, `AshTypescript.Rpc` | 7 |
| `Xaas.Governance` | `lib/xaas/governance.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshPaperTrail.Domain`, `AshAdmin.Domain` | 27 |
| `Xaas.Ledger` | `lib/xaas/ledger.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 4 |
| `Xaas.Marketplace` | `lib/xaas/marketplace.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 2 |
| `Xaas.Operations` | `lib/xaas/operations.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 17 |
| `Xaas.Platform` | `lib/xaas/platform.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 7 |
| `Xaas.Library` | `lib/xaas/library.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain`, `AshAi` | 5 |

## Next Read Library Domain Specification (`Xaas.Library`)

### Resources
1. **`Book`** (`lib/xaas/library/book.ex`): Catalog items with atomic updates (`:borrow_copy`, `:return_copy`), calculations (`:is_available`, `:has_multiple_copies`), and PubSub notifications (`library:books:events`, `library:books:inventory:<id>`).
2. **`Checkout`** (`lib/xaas/library/checkout.ex`): Circulation transactions with atomic triggers (`Xaas.Library.Changes.DecrementBookInventory`) and student-scoped PubSub notifications (`circulation:events`, `circulation:student:<user_id>`).
3. **`HoldRequest`** (`lib/xaas/library/hold_request.ex`): Reservation queues for unavailable titles.
4. **`Curation`** (`lib/xaas/library/curation.ex`): Librarian spotlight recommendations (`recommendations:curation_events`, `recommendations:grade:<grade_band>`).
5. **`RecommendationLog`** (`lib/xaas/library/recommendation_log.ex`): Audit trail of 6-factor weight vectors and rank outputs.

### Ash AI MCP Server Tools
Exposed at `/mcp` via `AshAi.Mcp.Router`:
- `:list_books` -> `Xaas.Library.Book.read`
- `:books_by_grade_band` -> `Xaas.Library.Book.by_grade_band`
- `:active_curations_for_grade` -> `Xaas.Library.Curation.active_for_grade`
