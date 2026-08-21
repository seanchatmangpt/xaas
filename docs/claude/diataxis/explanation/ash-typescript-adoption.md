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
  otp_app: :kanban,
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
extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshIam, AshTypescript.Resource]

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
the crash. This repo has no live `/rpc/run` HTTP endpoint mounted yet (out of scope for this
pass, same "resource/schema first, live wiring as disclosed follow-up" sequencing this repo
already uses elsewhere) -- the generated functions reference that path but nothing serves it.

## Real generated output

Two files, both real and non-empty:

- `assets/js/ash_types.ts` (664 lines) -- shared resource schema types
- `assets/js/ash_rpc.ts` (359 lines) -- RPC helper functions + per-action exports

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

- No live `/rpc/run`/`/rpc/validate` HTTP endpoint is mounted in
  `lib/kanban_web/router.ex` -- the generated `.ts` functions would 404 against this repo's
  real running server today. Wiring `AshTypescript.Rpc.Plug`/router forwarding is real,
  disclosed follow-up work, not attempted in this pass (task scope was codegen, not a live
  RPC transport).
- Only the remaining 46 already-JSON-API-wired resources were left untouched -- this pass's
  scope was the 3 named resources, not a repo-wide rollout.
- `Xaas.Ledger.*` and `Xaas.Accounts.User`/`Token` were not touched, consistent with
  `CLAUDE.md`'s "never blindly wire routes on sensitive resources" floor -- `ash_typescript`
  RPC exposure is a new customer-facing surface with the same access-control-first
  discipline as a JSON:API route.

## See Also

- `docs/claude/diataxis/explanation/architecture-overview.md` — whole-system map this doc is one narrow piece of
- `docs/claude/diataxis/reference/http-api-surface.md` -- real current HTTP route surface
  these 3 resources already had before this pass
- `docs/claude/diataxis/how-to/add-a-real-json-api-route-to-an-ash-resource.md` -- the
  read-only-route convention this pass's `rpc_action ..., :read` choice mirrors
- `docs/ASH-MIGRATION-PLAN.md` -- Phase 5 deferred customer-facing mutation-surface decision,
  which a future live-`/rpc` mutation RPC action would also need to resolve
