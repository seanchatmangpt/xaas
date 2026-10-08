# ash_typescript Adoption Decision

Real outcome: **adopted, real generated TypeScript for 3 resources**, real dep added, real
codegen task run, real `.ts` files produced. This document is the completed decision the
earlier evaluation-only pass on `ash_typescript` (https://hex.pm/packages/ash_typescript)
did not carry through to.

## Decision

Adopted. `{:ash_typescript, "~> 0.17"}` (real latest published version at decision time,
`0.17.3`, per hex.pm) is a real dep in `mix.exs`, wired against 3 real,
already-JSON-API-wired resources:

- `Xaas.Billing.Subscription`
- `Xaas.Marketplace.Provider`
- `Xaas.Accounts.Org`

## Real config added

`config/config.exs`:

```elixir
config :ash_typescript,
  otp_app: :xaas,
  output_file: "assets/js/ash_rpc.ts",
  output_field_formatter: :camel_case,
  input_field_formatter: :camel_case
```

`output_field_formatter`/`input_field_formatter` are not optional despite not being called
out as required in the package's own README example -- omitting them produced a real
`** (ArgumentError) Unsupported formatter: nil` crash from
`AshTypescript.FieldFormatter.compute_field_name/2` on the first `mix ash_typescript.codegen`
attempt (installed version `0.17.3`; this may be a real doc gap in that version, not
something this repo did wrong).

## Real per-resource wiring

Each resource gained `AshTypescript.Resource` in its `extensions:` list and a `typescript do
type_name "..." end` block, e.g. (from `lib/xaas/billing/subscription.ex`):

```elixir
extensions: [AshJsonApi.Resource, AshIam, AshTypescript.Resource]

typescript do
  type_name "BillingSubscription"
end
```

Same pattern applied to `lib/xaas/marketplace/provider.ex` (`MarketplaceProvider`) and
`lib/xaas/accounts/org.ex` (`AccountsOrg`).

## Real per-domain RPC wiring

Each domain gained `AshTypescript.Rpc` in its `extensions:` list and a `typescript_rpc do`
block exposing exactly one real read action per resource (no mutating RPC action exposed --
matches this repo's existing JSON:API convention of `get`/`index` on `:read` only, per
`docs/claude/diataxis/how-to/add-a-real-json-api-route-to-an-ash-resource.md`):

```elixir
# lib/xaas/billing.ex
typescript_rpc do
  resource Xaas.Billing.Subscription do
    rpc_action :list_billing_subscriptions, :read
  end
end
```

Same pattern in `lib/xaas/marketplace.ex` (`list_marketplace_providers`) and
`lib/xaas/accounts.ex` (`list_accounts_orgs`).

## Real codegen command that works

The README's advertised `mix ash.codegen --dev` did not exercise `ash_typescript`'s own
generator in this repo's install; the real, dedicated mix task discovered via
`mix help | grep -i typescript` is:

```bash
mix ash_typescript.codegen --run-endpoint /rpc/run --validate-endpoint /rpc/validate
```

`--run-endpoint`/`--validate-endpoint` are real, required-in-practice flags for this
installed version: the mix task passes `run_endpoint: nil` / `validate_endpoint: nil`
explicitly into the codegen opts keyword list when neither the CLI flag nor a
`config :ash_typescript, run_endpoint: ...` app-env value is set, which defeats the
generator's own internal `Keyword.get(opts, :run_endpoint, "/rpc/run")` default (the key
is present with a `nil` value, not absent) and crashes with
`** (FunctionClauseError) no function clause matching in AshTypescript.Helpers.format_ts_value/1`
on the `nil`. Passing the flags explicitly (or setting `config :ash_typescript,
run_endpoint: "/rpc/run", validate_endpoint: "/rpc/validate"` in `config/config.exs`) avoids
the crash. (Adoption-pass note: at that time no `/rpc/run` HTTP endpoint was mounted.
Both endpoints are now mounted under `/internal-api` -- see "Status at v26.10.6"; the
endpoints are also set in `config/config.exs` via `run_endpoint`/`validate_endpoint`,
so the explicit flags are no longer required in practice.)

## Real generated output

Two files, both real and non-empty (line counts below are the adoption-pass snapshot;
current counts are in the Status block):

- `assets/js/ash_types.ts` (664 lines at adoption; 939 at v26.10.6) -- shared resource schema types
- `assets/js/ash_rpc.ts` (359 lines at adoption; 400 at v26.10.6) -- RPC helper functions + per-action exports

Real excerpt from `assets/js/ash_types.ts` (all 3 resources present, real attribute types,
real enum constraint values, real nullability):

```typescript
// BillingSubscription Schema
export type BillingSubscriptionResourceSchema = {
  __type: "Resource";
  __primitiveFields: "id" | "orgId" | "stripeCustomerId" | "stripeSubscriptionId" | "tier" | "status" | "currentPeriodEnd";
  id: UUID;
  orgId: string;
  stripeCustomerId: string;
  stripeSubscriptionId: string | null;
  tier: "standard";
  status: "active" | "canceled" | "incomplete" | "past_due";
  currentPeriodEnd: UtcDateTime | null;
};
```

Real excerpt confirming all 3 RPC functions were generated (`grep` against the real file):

```
192:export async function listAccountsOrgs<...>(
267:export async function listBillingSubscriptions<...>(
342:export async function listMarketplaceProviders<...>(
```

## Compile status

`mix compile --force` is clean (only the pre-existing, unrelated Gettext-backend deprecation
warning; zero errors, zero new warnings from this change).

## Real scope not covered by this pass (disclosed, not done)

Historical scope note from the original adoption pass; superseded on the transport
point by "Status at v26.10.6" below.

- ~~No live `/rpc/run`/`/rpc/validate` HTTP endpoint is mounted~~ -- as of v26.10.6 both
  endpoints are mounted and courted (see Status block below).
- Only the remaining 46 already-JSON-API-wired resources were left untouched -- this pass's
  scope was the 3 named resources, not a repo-wide rollout.
- `Xaas.Ledger.*` and `Xaas.Accounts.User`/`Token` were not touched, consistent with
  `CLAUDE.md`'s "never blindly wire routes on sensitive resources" floor -- `ash_typescript`
  RPC exposure is a new customer-facing surface with the same access-control-first
  discipline as a JSON:API route.

## Status at v26.10.6

Verified 2026-10-07 against the working tree at `feat/playwright-surface` (W820 lane;
no W813 receipt file is landed in `docs/sjira/v26.10.6/plans/`, so verification used the
router/config/tests directly).

**Generated TS artifacts** (regenerated by `mix ash_typescript.codegen`, manifest
`Xaas.AshTypescriptManifest` per `config/config.exs:187`):

- `assets/js/ash_rpc.ts` (400 lines) -- RPC helpers + per-action exports
- `assets/js/ash_types.ts` (939 lines) -- shared resource schema types

**RPC routes** (`lib/xaas_web/router.ex:101-102`, inside the `/internal-api` scope
behind `RequireInternalApiToken`, served by `XaasWeb.AshTypescriptRpcController`
delegating to `AshTypescript.Rpc.run_action/validate_action`):

- `POST /internal-api/rpc/run`
- `POST /internal-api/rpc/validate`

The generated clients target these paths via `config/config.exs:182-183`
(`run_endpoint: "/internal-api/rpc/run"`, `validate_endpoint: "/internal-api/rpc/validate"`).

**Domain coverage** (real grep `typescript_rpc`/`rpc_action` over `lib/xaas/*.ex` --
4 domains, 4 rpc actions):

| Domain | Resource | rpc_action | Location |
|---|---|---|---|
| `Xaas.Accounts` | `Xaas.Accounts.Org` | `:list_accounts_orgs, :read` | `lib/xaas/accounts.ex:10-14` |
| `Xaas.Billing` | `Xaas.Billing.Subscription` | `:list_billing_subscriptions, :read` | `lib/xaas/billing.ex:10-14` |
| `Xaas.Marketplace` | `Xaas.Marketplace.Provider` | `:list_marketplace_providers, :read` | `lib/xaas/marketplace.ex:14-18` |
| `Xaas.Operations` | `Xaas.Operations.ProjectMeasure.Measurement` | `:measure_project, :measure` | `lib/xaas/operations.ex:22-26` |

**Courts**: `test/xaas_web/rpc_surface_deepening_test.exs` exercises both endpoints over
real HTTP (`rpc/run` success envelope + policy-denied typed envelope; `rpc/validate`
typed validation payload).

**release_audit pinning**: `check_rpc_alignment/1`
(`lib/mix/tasks/xaas.release_audit.ex:313-349`) fails the audit unless
`config/config.exs` contains the canonical `run_endpoint`/`validate_endpoint` strings and
`lib/xaas_web/router.ex` mounts both controller routes (W636 repointed the audit's router
reference from the pre-rename `lib/kanban_web/router.ex` and relaxed the mount match to
the paren spelling; see `docs/sjira/v26.10.6/plans/w636-rpc-repoint.md`).

**Dependency**: `{:ash_typescript, "~> 0.17"}` (`mix.exs:137`); config requires the
0.18-era mandatory `manifest:` module (`config/config.exs:186-187`).

## Verified 2026-10-07 (W984hv truth-pass)

Every load-bearing claim above re-checked against the working tree at `feat/playwright-surface`.
All substantive claims hold; only line-number citations drifted. Corrections (disk-verified):

- Router mount is at `lib/xaas_web/router.ex:109-110` (doc said 101-102) -- `post("/rpc/run",
  AshTypescriptRpcController, :run)` / `post("/rpc/validate", AshTypescriptRpcController,
  :validate)`, confirmed inside the token-gated `/internal-api` scope (`pipe_through`
  includes `:require_internal_api_token`).
- `run_endpoint`/`validate_endpoint` config is at `config/config.exs:180-181` (doc said
  182-183); the mandatory `manifest: Xaas.AshTypescriptManifest` is at `config/config.exs:185`
  (doc said 186-187).
- `{:ash_typescript, "~> 0.17"}` is at `mix.exs:153` (doc said 137).
- `check_rpc_alignment/1` now lives at `lib/mix/tasks/xaas.release_audit.ex:596` (doc said
  313-349); behavior unchanged: fails-closed unless both canonical endpoint strings are in
  `config/config.exs` and both controller routes are in `lib/xaas_web/router.ex`.

Confirmed unchanged and real:

- Generated artifacts: `assets/js/ash_rpc.ts` (400 lines) and `assets/js/ash_types.ts`
  (939 lines) -- counts match the v26.10.6 Status block exactly.
- All 4 generated RPC exports present in `assets/js/ash_rpc.ts`: `listAccountsOrgs` (:193),
  `listBillingSubscriptions` (:268), `listMarketplaceProviders` (:343), `measureProject`
  (:380).
- Domain table exact: `Xaas.Accounts` (`lib/xaas/accounts.ex:10-14`, `:list_accounts_orgs,
  :read`), `Xaas.Billing` (`lib/xaas/billing.ex:10-14`, `:list_billing_subscriptions, :read`),
  `Xaas.Marketplace` (`lib/xaas/marketplace.ex:14-18`, `:list_marketplace_providers, :read`),
  `Xaas.Operations` (`lib/xaas/operations.ex:21-25`, `:measure_project, :measure` --
  a mutating-generic `bypass`-declared action, not a plain `:read`; still no
  customer-facing mutating RPC beyond this).
- `AshTypescript.Resource` extension present on all 4 resources (`subscription.ex:110`,
  `provider.ex:22`, `org.ex:79`, `project_measure/measurement.ex:21`); `AshTypescript.Rpc`
  on all 4 domains.
- Court `test/xaas_web/rpc_surface_deepening_test.exs` exists and is real: W813 deepening
  court, real ConnCase over the real router and sandboxed Postgres, no mocks; covers
  success envelope, typed validation payload, unknown-action typed error, W723 auth floor,
  W636 repoint, determinism.
- Controller `lib/xaas_web/controllers/ash_typescript_rpc_controller.ex` present, delegates
  to `AshTypescript.Rpc`.
- **GraphQL status**: this doc makes no "typescript replaces graphql" claim and needs none --
  graphql was excised (W984ao/W984et: `ash_graphql`/`absinthe*` unlocked from mix.lock,
  no graphql scope in the router). The only live graphql-adjacent surface is
  `lib/xaas/semantics/vkg.ex` `graphql/2` via `ash_r2rml`, unrelated to ash_typescript.
  Excision trail: `docs/sjira/v26.10.6/plans/w984et-probe.md`.

No `w984ho` RPC probe receipt file exists in `docs/sjira/v26.10.6/plans/` as of this pass
(glob returned no matches), so the router/config/controller greps above are the
verification of record for the RPC surface.

## See Also

- `docs/claude/diataxis/explanation/architecture-overview.md` — whole-system map this doc is one narrow piece of
- `docs/claude/diataxis/reference/http-api-surface.md` -- real current HTTP route surface
  these 3 resources already had before this pass
- `docs/claude/diataxis/how-to/add-a-real-json-api-route-to-an-ash-resource.md` -- the
  read-only-route convention this pass's `rpc_action ..., :read` choice mirrors
- `docs/archive/ASH-MIGRATION-PLAN.md` (historical) -- Phase 5 deferred customer-facing mutation-surface decision,
  which a future live-`/rpc` mutation RPC action would also need to resolve
