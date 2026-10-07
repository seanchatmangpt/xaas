# W723 — RequireInternalApiToken Deepening Court

- **Standing**: ALIVE (16/16 real test passes on the exact subject)
- **Lane**: W723, v26.10.6 campaign, repo /Users/sac/xaas, branch
  `feat/playwright-surface`, HEAD a0723bf6
- **Subject**: `test/xaas_web/require_internal_api_token_deepening_test.exs`
  (new, sole written file) against
  `lib/xaas_web/plugs/require_internal_api_token.ex`
- **Command** (real):
  ```
  PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW723 \
    mix test test/xaas_web/require_internal_api_token_deepening_test.exs
  ```
- **Real tail**:
  ```
  Finished in 1.1 seconds (0.00s async, 1.1s sync)
  Result: 16 passed
  ```

## What the court pins (all real plug/router invocations, zero mocks)

- (a) absent env + no header -> 503, exact body
  `%{"error" => "internal_api_misconfigured", "detail" => "INTERNAL_API_TOKEN is not set on the server"}`, halted
- (b) absent env + wrong bearer -> still 503 (fail-closed outranks auth)
- (c) present env + no header -> 401, exact body
  `%{"error" => "unauthorized", "detail" => "missing or invalid Bearer token"}`, halted
- (d) present env + wrong token -> 401 exact, halted
- (e) valid token -> plug passes through unhaltered, `assigns[:current_org]`
  nil (legacy env tier), and a real full-router dispatch with the token
  reaches `/internal-api/capability_liveness_receipts` (no 401/503)
- (f) Bearer parse discipline of `bearer_token/1`: exact `["Bearer " <> token]`
  single-element match, nonempty token; lowercase/ALL-CAPS scheme, extra
  whitespace, missing space, empty credentials all 401 (empty credentials
  under absent env = 503, honor the no-header fail-closed path); multiple
  headers unconstructible via put_req_header (replaces) — last value wins;
  header-name case: Plug test mode raises `InvalidHeaderError` on
  non-lowercase keys and `get_req_header/2` lookup is case-sensitive
- (g) content-negotiation matrix pinned as REAL contract: on
  `/internal-api` an incompatible Accept (`application/json`, `text/plain`)
  raises `Phoenix.NotAcceptableError` BEFORE the token floor even for a
  completely unauthenticated probe (W699/W299c class: 406 outranks auth on
  this scope — the W299c fix moved the floor first only on the `/api`
  forward scope, not the json-api router scope); with a VALID token the
  same incompatible Accept also raises; no Accept header at all defaults
  to json-api and hits the auth floor (401/503, never 406)

## Findings (real, run-discovered)

1. The W699 406-vs-401 leak class is still real on the `/internal-api`
   json-api router scope: unauthenticated + `Accept: application/json`
   => `Phoenix.NotAcceptableError` (leaks `Expected one of ["json-api"]`).
   Only the `/api` forward scope has the floor-before-`:accepts` fix.
2. Plug test mode hard-rejects non-lowercase header keys
   (`validate_header_key_normalized_if_test!`), so header-name casing is
   guaranteed upstream; the plug only ever sees lowercase keys.

## Env discipline

`with_env/2` swaps `INTERNAL_API_TOKEN` (delete for absent-env cases,
restore for present-env) with both in-block restore and `on_exit`
restore — the existing repo idiom. No mocks; real sandboxed Postgres via
`ConnCase` (the DB-token `verify/1` path runs for real and falls through
to the env tier when no row matches).

## Transport notes

- Cold lane build ran ~15 min (background); test run itself 1.1 s.
- `_build-laneW723` could NOT be deleted at lane end: `rm -rf` was denied
  by the permission system (same outcome as W699's lane). Left for the
  coordinator at `/Users/sac/xaas/_build-laneW723`.
