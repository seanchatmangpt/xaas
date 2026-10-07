# W808 — RouteFeatureFlags :approve lawful HTTP exposure

Lane W808, repo `/Users/sac/xaas`, branch `feat/playwright-surface`, base HEAD `a0723bf6`. No commit (coordinator owns commits).

## Order

From W785's receipt (`docs/sjira/v26.10.6/plans/w785-overdraft-policy.md`), flagged UNKNOWN:
W792's `patch(:approve)` collided with `patch(:update)` on `/:id` under
`ValidateNoOverlappingRoutes`; W785 unblocked compilation by commenting the route out.
`:approve` was callable only via the Ash code interface, not HTTP.

## Decision (route-qualified PATCH, option: dedicated path segment)

Read the dep source, not docs: `deps/ash_json_api/.../validate_no_overlapping_routes.ex`
groups routes by `{method, route}` **exact path**, and
`prepend_route_prefix.ex` prepends the resource `base("/route_feature_flags")` to every
route's path. So a route-qualified patch on a **distinct relative path** is lawful and
cannot collide:

```elixir
patch(:approve, route: ":id/approve")
```

→ serves `PATCH /api/route_feature_flags/:id/approve` (via `XaasWeb.ApiRouter`,
prefix `/api`, token-gated by `RequireInternalApiToken`; `SetInternalApiSystemActor`
supplies the `:internal_api` actor). Distinct from `patch(:update)`'s
`/route_feature_flags/:id`; the overlap check passes because the paths differ.

## Before / After

- Before: routes block had `patch(:update)` only; `# patch(:approve)` commented out
  (W785 unblock). `:approve` reachable only through the Ash code interface
  (courts 6a/6b/6c).
- After: `patch(:approve, route: ":id/approve")` registered; verified in-test as
  `AshJsonApi.Resource.Info.routes/1` returning exactly one patch route for `:approve`
  at `/route_feature_flags/:id/approve`, and `:update` still at `/route_feature_flags/:id`.

## New courts (deepening suite, tests (9a)/(9b))

- **(9a)** route registration: exactly one `:approve` patch route with the exact path;
  `:update` patch path unchanged. **Mutation target**: this is the assert that fails if
  the route line is removed again — `assert [_] = approve_routes` fails with `[]`
  (match error on empty list). Any re-comment/removal of the line is killed here in the
  deepening suite alone.
- **(9b)** real end-to-end HTTP approve through `XaasWeb.Endpoint` dispatch
  (`Phoenix.ConnTest.dispatch/5`): token-bearing vnd.api+json PATCH to
  `/api/route_feature_flags/:id/approve` returns 200 with `approved_by: "checker-9"`
  in the response document AND the real Postgres row re-read shows `approved_by` moved;
  the identical request without the Bearer token is refused 401 before any Ash policy
  runs and the row is unchanged (checked by real re-read). W792's refusal courts (6a–6d,
  (1b)) remain green in the same run.

Chicago discipline: real endpoint dispatch, real token from `INTERNAL_API_TOKEN`, real
sandboxed Postgres row state. No mocks.

## Verification (real output, PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW808)

- `mix test test/xaas/platform/platform_route_deepening_test.exs` → **19 passed, 0 failed**
  (17 prior + 2 new).
- `mix test test/xaas/platform/ test/xaas_web/controllers/route_feature_flags_controller_test.exs`
  → **29 passed, 1 excluded** (stress tag), zero failures — W792's maker-checker refusal
  courts and the pre-existing POST/PATCH controller courts all green against the new
  route block.

## Transport failures this session (disclosed)

1. First full-compile in the fresh lane build root hit a transient Elixir-1.20.2
   set-theoretic type-checker error on `lib/xaas/operations/validations/incident_resolved_is_terminal.ex`
   (a file UNTRACKED in git — another lane's in-flight work, untouched by this lane).
   Retry compile → `Generated xaas app`, EXIT=0. Classified transient parallel-compile
   flake, not session-introduced.
2. First test compile: `put_req_header/3` not in scope in a plain `ExUnit.Case` — fixed
   with `import Plug.Conn, only: [put_req_header: 3]`.

## Standing

**ALIVE** on the RouteFeatureFlags HTTP surface: 19/19 + 29/29 green, route presence is
mutation-covered ((9a) is the kill target), real HTTP path exercised with auth refusals.
Lane build root `_build-laneW808` left in place for the coordinator (fanout cleanup law:
deleting here — see note below if present at integration).
