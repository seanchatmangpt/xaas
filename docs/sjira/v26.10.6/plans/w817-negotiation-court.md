# W817 — JSON:API Content-Negotiation Court (dedicated)

- **Standing**: ALIVE (16/16 real test passes on the exact subject)
- **Lane**: W817, v26.10.6 campaign, repo /Users/sac/xaas, branch
  `feat/playwright-surface`, HEAD a0723bf6
- **Subject**: `test/xaas_web/jsonapi_content_negotiation_test.exs` (new,
  sole written file) against `lib/xaas_web/router.ex` pipelines
  (`:require_internal_api_token` -> `:internal_api` on both AshJsonApi
  forward scopes) and the two generated routers
  (`lib/xaas_web/internal_api_router.ex`, `lib/xaas_web/api_router.ex`)
- **Command** (real):
  ```
  PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW817 \
    mix test test/xaas_web/jsonapi_content_negotiation_test.exs
  ```
- **Real tails** (two independent runs, different ExUnit seeds):
  ```
  Running ExUnit with seed: 908806, max_cases: 32
  Finished in 0.6 seconds (0.00s async, 0.6s sync)
  Result: 16 passed
  ```
  ```
  Running ExUnit with seed: 221205, max_cases: 32
  Finished in 0.7 seconds (0.00s async, 0.7s sync)
  Result: 16 passed
  ```

## The matrix courted (all real full-router ConnCase dispatches)

| # | scope | auth | Accept / Content-Type | real outcome (pinned) |
|---|---|---|---|---|
| a1 | /internal-api | valid Bearer | Accept: application/vnd.api+json | 200 json-api document, response `content-type` header contains `application/vnd.api+json`, real sandboxed row returned (data/attributes/id) |
| a2 | /api | valid Bearer | Accept: application/vnd.api+json | 200 json-api document, same shape, same response header |
| b1 | /internal-api | valid Bearer | Accept: application/json | raised `Phoenix.NotAcceptableError` "Expected one of [\"json-api\"]" |
| b2 | /api | valid Bearer | Accept: application/json | same raised NotAcceptableError |
| b3 | /internal-api | none | Accept: application/json | 401 exact body `%{"error" => "unauthorized", "detail" => "missing or invalid Bearer token"}` — never 406 (W739 cell) |
| b4 | /api | none | Accept: application/json | 401 exact body — never 406 (W299c cell) |
| c1 | /api | valid Bearer | POST Content-Type: application/json | real 415 response document (`errors` key) from AshJsonApi |
| c2 | /api | valid Bearer | POST Content-Type: application/vnd.api+json | NOT refused for media type — 201/403/422 allowed, 415 banned |
| c3 | /api | valid Bearer | POST Content-Type: text/plain | raised `Plug.Parsers.UnsupportedMediaTypeError` "unsupported media type text/plain" |
| d1 | /api | none | Accept: application/vnd.api+json | 401 floor, never 406 |
| d2 | /api | none | no Accept header | 401 floor (json-api default), never 406 (W723 g1 cell, /api side) |
| d3 | /api | none | Accept: text/plain | 401 floor, never 406 |
| d4 | /api | valid Bearer | Accept: text/plain | raised NotAcceptableError |
| e1–e3 | both | mixed | — | determinism: happy read + both floor cells byte-identical across two replays each |

Happy-cell rows are real: `Ash.create!` with `authorize?: false` into
sandboxed Postgres, read back through the real mounted router.

## Findings (real, run-discovered)

1. **Content-Type discipline is SPLIT, not uniform.** POST with
   `Content-Type: application/json` gets a real 415 response document
   (AshJsonApi's own media-type check), but `text/plain` never reaches
   AshJsonApi — `Plug.Parsers` raises `UnsupportedMediaTypeError` first
   (endpoint -> ApiRouter's Plug.Parsers -> AshJsonApi). Two different
   refusal mechanisms for the same JSON:API spec rule (servers MUST
   answer 415). Same evidentiary register as the Accept side: in this
   stack raised exceptions ARE the 406/415 behavior (Phoenix `:accepts`
   raises NotAcceptableError, courted identically in W723 g4).
2. The W739/W299c/W150 floor-first ordering holds on BOTH scopes across
   the full unauthenticated x incompatible-Accept cells: every such cell
   returns the 401 floor body, never a 406. No leak regression.
3. The happy matrix cell (a1/a2) doubles as a composed-surface probe of
   the same resource (`capability_liveness_receipts`) on both routers,
   asserting the response `content-type` header carries
   `application/vnd.api+json` — which the W805 surface court did not
   pin.

## Env discipline

`INTERNAL_API_TOKEN` is set by `test/test_helper.exs`
(`test-only-internal-api-token`); the token floor runs for real on every
dispatch. Rows via real Ash creates into sandboxed Postgres; org rows
likewise. No mocks; zero interaction assertions.

## Transport notes

- Lane build seeded by copying `_build-laneW816` (read-only on the
  source); incremental compile ~2 min, test runtime 0.6-0.7 s.
- One real test-run failure during development: c3 initially asserted a
  415 response; the run surfaced the raised UnsupportedMediaTypeError
  instead, and the assert was corrected to pin the real behavior.
- Lane-end lease: `rm -rf /Users/sac/xaas/_build-laneW817` was attempted
  at lane end and DENIED by the permission system — the dir is left for
  the coordinator at `/Users/sac/xaas/_build-laneW817` (same outcome as
  the W723 lane).
