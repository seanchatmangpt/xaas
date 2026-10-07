# W739 — /internal-api 406-before-auth leak fix (W723 finding 1)

Subject: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface (lane W739, uncommitted).

## Before

The `/internal-api` catch-all forward scope (`lib/xaas_web/router.ex`) listed
`:internal_api` (carrying `plug(:accepts, ["json-api"])`) before
`:require_internal_api_token`. Pipeline order = plug order, so an
unauthenticated request with an incompatible Accept header (e.g.
`application/json`) raised `Phoenix.NotAcceptableError` (406, body leaking
`Expected one of ["json-api"]`) before the token floor ever ran. Identical
class to W150 (/api/workbench) and W299c (/api forward).

## Fix

Same minimal W299c pattern: reordered the forward scope's pipeline to

```elixir
pipe_through([
  :require_internal_api_token,
  :internal_api,
  :set_internal_api_system_actor
])
```

with a W739 comment. Authenticated behavior unchanged — the floor passes
authenticated requests through to the same `:accepts` check (g4 still pins
that json-api negotiation is still enforced post-auth).

## Files

- `lib/xaas_web/router.ex` — pipeline reorder + comment (only change).
- `test/xaas_web/require_internal_api_token_deepening_test.exs` — g2/g3
  flipped from pinning the 406 leak as real behavior to regression courts
  (floor 401 + exact `@unauthorized_body`, refute 406); g2 carries the
  mutation rationale. No other edits.

## Verification (real output)

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW739 mix test test/xaas_web/require_internal_api_token_deepening_test.exs
Result: 16 passed        (after fix)

mix test test/xaas_web/ggen_workbench_auth_floor_test.exs
Result: 4 passed         (W150-class sibling court, no regression)

MUTATION (revert router reorder in place, rerun):
  14/16 passed — g2 AND g3 fail with
  ** (Phoenix.NotAcceptableError) no supported media type in accept header.
     Expected one of ["json-api"] but got the following formats:
  → the exact-body assert (Jason.decode!(conn.resp_body) == @unauthorized_body
    under assert conn.status == 401) is the failing assert on revert.
Then restored; rerun: 16 passed; diff vs saved fix copy clean.
```

Note: no separate `test/xaas_web/require_internal_api_token_test.exs` exists
in the tree; the deepening file is the complete token-floor court, so it is
the "existing suite" that was held green (16/16 before and after, g2/g3
updated as part of the fix).

## Mutation rationale

Reverting the reorder puts `:accepts(["json-api"])` back ahead of the token
floor; the g2 dispatch raises `Phoenix.NotAcceptableError` before the plug
writes the 401 body, so `assert conn.status == 401` /
`Jason.decode!(conn.resp_body) == @unauthorized_body` fails. g3 is the
second Accept variant (`text/plain`) of the same court.

## Standing

ALIVE — fix executed on the exact subject (a0723bf6 working tree), floor
response witnessed through the full router, mutation confirmed the court is
non-vacuous. Uncommitted per lane law (coordinator owns commits).
