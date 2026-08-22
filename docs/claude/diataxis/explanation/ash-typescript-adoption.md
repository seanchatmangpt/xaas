# AshTypescript adoption

XaaS v26.8.21 uses AshTypescript 0.17.x as a generated projection of selected Ash actions. It is not a parallel API framework and generated TypeScript is never edited by hand.

## Admitted RPC surface

Four resources are currently registered with `AshTypescript.Rpc`:

| Domain | Resource | RPC action | Semantics |
| --- | --- | --- | --- |
| Accounts | `Xaas.Accounts.Org` | `list_accounts_orgs` | read |
| Billing | `Xaas.Billing.Subscription` | `list_billing_subscriptions` | read |
| Marketplace | `Xaas.Marketplace.Provider` | `list_marketplace_providers` | read |
| Operations | `Xaas.Operations.ProjectMeasure.Measurement` | `measure_project` | observe/read-only generic action |

This is a deliberately bounded set. Ledger and authentication/token resources are not mechanically added to RPC merely because a generator can describe them.

## Generated files

AshTypescript owns:

- `assets/js/ash_rpc.ts`
- `assets/js/ash_types.ts`

Regenerate with:

    mix ash_typescript.codegen

CI qualification must prove regeneration produces zero committed diff. `mix ash_typescript.codegen --check` is the preferred non-mutating gate when supported by the installed version.

## Runtime endpoints

Generated clients target:

- `POST /internal-api/rpc/run`
- `POST /internal-api/rpc/validate`

Both routes are mounted in `KanbanWeb.Router` before the `/internal-api` catch-all and pass through `KanbanWeb.Plugs.RequireInternalApiToken`. `KanbanWeb.AshTypescriptRpcController` delegates directly to `AshTypescript.Rpc.run_action/3` and `validate_action/3`.

POST is the RPC transport envelope, not evidence that the underlying action mutates state. The admitted v26.8.21 RPC set is read/observe-only. Any future mutation RPC requires its own action/policy/authority design and cannot be inferred from this transport.

## Field formatting

Configuration uses camelCase for generated input/output fields while Ash resource/action names remain canonical Elixir atoms in the BEAM application.

## Project measurement projection

`measure_project` is generated from `Xaas.Operations.ProjectMeasure.Measurement`. The exact commit SHA remains a constrained Ash type; the Reactor performs GitHub GET observation and semantic admission; the generated client does not bypass either layer.

GraphQL separately exposes `measure_json` because the receipt-bearing measurement payload is an open map and therefore has no honest fixed GraphQL object type. The TypeScript RPC projection may represent the Ash action according to AshTypescript's generated schema, but it does not redefine the receipt.

## Release invariant

The following must agree on every release candidate:

1. domain `typescript_rpc` declarations;
2. resource `AshTypescript.Resource` configuration;
3. configured run/validate endpoint paths;
4. mounted Phoenix controller routes;
5. generated TypeScript output;
6. release documentation.

`mix xaas.release_audit` checks endpoint alignment and the exact-head CI court checks generated-code drift.
