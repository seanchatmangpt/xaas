# W984f — route-castle type-only gate-5 residual (disposition (b): test fixed to lawful contract)

Lane: W984f, xaas v26.10.6 campaign, canonical checkout /Users/sac/xaas,
branch feat/playwright-surface @ 49a719ab. No commits (lane law). Build root
`_build-laneW984f` deleted at lane close.

## Demand analysis (root cause)

Failing test (W982e persistent #1, ex-W972 deterministic #9):
`Xaas.Operations.RouteCastleRunSurfaceTest` "the private :execute action is
still unroutable via the GraphQL surface too (type-only)"
(`test/xaas/operations/route_castle_run_surface_test.exs:195`).

What it demanded: POST /api/graphql with `accept: application/json` must raise
`Phoenix.NotAcceptableError` (~r/Expected one of \["json-api"\]/) — i.e. the
/api scope content-negotiates json-api ONLY, so no GraphQL document is
constructible there at all.

Why it fails on the current tree: SPEC-30 (W975b, commit 691e0a93) deliberately
mounted `/api/graphql` (Absinthe.Plug, Xaas.GraphqlSchema) on the `:api`
pipeline (`plug(:accepts, ["json"])` — router.ex:302-309), behind the same
`:require_internal_api_token` floor. Its own court
(`test/xaas_web/graphql_http_surface_test.exs:36,44`) pins `application/json`
acceptance as the lawful SPEC-30 contract. The route-castle pin predates the
SPEC-30 mounting and its 406 mechanism is now impossible without breaking the
deliberate GraphQL surface.

The doctrine substance (private `:execute` must be unreachable via GraphQL) is
nevertheless TRUE on the current tree:
`lib/xaas/operations/route_castle_run.ex` declares
`graphql do type(:route_castle_run) end` with NO `queries`/`mutations` block —
the schema has no field that could route `:execute` or any read. Confirmed by
the real wire: POST of `query { routeCastleRuns { id } }` answers 200 with
field errors and `data.routeCastleRuns == nil`, and writes no durable
ActuationIntent/ActuationReceipt rows.

## Disposition: (b) — test corrected to the lawful contract

Rewrote the test (`route_castle_run_surface_test.exs:195`, disclosed in-file):

1. POST the GraphQL document with `accept: application/json` (real SPEC-30
   contract) and assert the real answer: 200, `%{"errors" => errors}` with
   `data.routeCastleRuns` nil (no such field — type-only, no routed read).
2. Assert the unrouted attempt wrote no durable actuation evidence: no
   ActuationReceipt with `resource_module == inspect(RouteCastleRun)` and
   `action == "execute"`; no ActuationIntent with the attempt's
   `subject_id == "system:w858-web-execute-attempt"`.

No production code changed. No graphql_schema.ex edit (W983h hot file
untouched — the fix required none). No router change (the SPEC-30 pipeline
contract is deliberate).

Two in-iteration corrections to my own first drafts: the intent assertion
initially asserted table emptiness (shared sandbox tables carry unrelated
rows) and used the wrong field (`subject` vs `subject_id`); both scoped/fixed.

## Verification (real tails, fresh root `_build-laneW984f`)

| run | scope | result |
|---|---|---|
| baseline (pre-edit, current tree) | route_castle_run_surface_test.exs | 9/10, the type-only test failed with "Expected exception Phoenix.NotAcceptableError but nothing was raised" (exact W982e reproduction) |
| post-fix run 1 | same file | 10 passed |
| post-fix run 2 | same file | 10 passed |
| adjacent run 1 | castle_bridge + castle_execute_court + refusal_negative ×4 batches | 67 passed, 2 excluded |
| adjacent run 2 | same | 67 passed, 2 excluded |

Adjacent file NOT run: `test/xaas_web/graphql_http_surface_test.exs` —
currently does not compile (MismatchedDelimiterError at :319, unclosed `~s(`
delimiter). Confirmed ` M` in git status: a sibling lane's in-flight edit
(W983h batch-4 territory). Not mine to touch; disclosed here for the
coordinator.

Commands:
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984f mix test ...`

## Standing

Route-castle gate-5 residual: **ALIVE** (test witnessed green ×2 on a fresh
lane root; doctrine pinned at the schema level with a real no-side-effect
wire assertion). Gate-5 falsifier (0 failures on a quiescent tree) advances by
one: persistent residual #1 of 5 is closed as a test-contract correction, not
a production gap.

Mock gate: no mocks introduced (Chicago-style, real ConnCase/Absinthe wire).
