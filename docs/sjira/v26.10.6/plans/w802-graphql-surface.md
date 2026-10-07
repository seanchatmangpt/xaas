# W802 — AshGraphql surface: compiled schema, no HTTP mount

- **Lane**: W802, xaas v26.10.6, branch `feat/playwright-surface`, HEAD `a0723bf6`
- **Question**: is the AshGraphql surface (wired on most domains per
  `docs/claude/diataxis/reference/ash-configuration.md`) actually exposed over HTTP?
- **Answer**: **NO — typed finding (b).** `Xaas.GraphqlSchema` compiles with
  `AshGraphql` wired over `Xaas.Operations`, `Xaas.Library`, `Xaas.Marketplace`
  (plus the stock `sayHello` sample query), but no route, plug, or endpoint
  forward references it anywhere in `lib/` or `config/`. The surface serves no
  HTTP.

## Grep matrix (real, run 2026-10-07, HEAD a0723bf6)

| probe | target | hits |
|---|---|---|
| `grep -i "graphql\|gql"` | `lib/xaas_web/router.ex` | **0** |
| `grep -rn "GraphqlSchema\|Absinthe.Plug"` | `lib/` + `config/` | only `lib/xaas/graphql_schema.ex` (its own definition + `import_types`) |
| `grep -rn "Absinthe\|graphql\|gql"` | `lib/xaas_web/endpoint.ex`, `internal_api_router.ex`, `api_router.ex` | 0 |
| `grep -rn "graphql"` | `config/*.exs` | 1 — `config/config.exs:169: config :ash_graphql, authorize_update_destroy_with_error?: true` (runtime config, not a route) |
| `grep -rln "absinthe"` | `test/` | 0 |
| `grep -cin "graphql"` | `lib/xaas_web/router.ex` | 0 |

## What exists

`lib/xaas/graphql_schema.ex` — `use Absinthe.Schema` + `use AshGraphql,
domains: [Xaas.Operations, Xaas.Library, Xaas.Marketplace]` — the schema body
is stock installer output (sample `sayHello` query, empty
mutation/subscription blocks). Only three of the ash-configuration domains are
wired in. `{:ash_graphql, "~> 1.0"}` in `mix.exs:134` is the only other
graphql trace in the tree.

## Typed gaps

- `GAP(graphql-http-mount)`: no `Absinthe.Plug` forward on any router scope.
  Any graphql query POSTed to the app hits the `/api`/`/internal-api` routers
  or 404s; nothing serves graphql.
- `GAP(graphql-domain-coverage)`: even if mounted, only 3 of the
  ash-configuration domains (Operations, Library, Marketplace) are wired into
  the schema; most domains named in `ash-configuration.md` are not.
- `GAP(graphql-auth-floor)`: no graphql scope exists, so no auth gate is pinned;
  if mounted later it must go behind the same `:require_internal_api_token`
  floor as the other API surfaces, per router doctrine.

## Standing

`UNSUPPORTED(graphql-http-surface)` — evidence over invention: no test file
added (lane instruction (b): receipt only, no invented route, no invented
queries against a nonexistent endpoint).

## Verification commands

```bash
grep -n -i "graphql\|gql" lib/xaas_web/router.ex          # 0 hits
grep -rn "GraphqlSchema\|Absinthe.Plug" lib config        # definition only
grep -rn "Absinthe\|graphql" lib/xaas_web/endpoint.ex \
      lib/xaas_web/internal_api_router.ex lib/xaas_web/api_router.ex  # 0 hits
grep -rn "graphql" config/*.exs                            # 1: config.exs:169 ash_graphql runtime config, no route
# schema compiles: PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW802 mix compile
# => "Generated xaas app", exit 0 (2026-10-07)
```

## Cleanup

`_build-laneW802` to be deleted at lane close.
