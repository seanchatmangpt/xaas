# W150 — Auth floor fixes (/api/workbench + /a2a parse floor)

backfilled by coordinator from lane completion report

## Subject

- Lane: W150, batch 3, v26.10.6 convergence, repo /Users/sac/xaas

## Changes

(a) /api/workbench pipeline reordered to `[:require_internal_api_token, :api]` —
token floor now runs before `:accepts`, closing the 406-before-auth class
(unauthenticated requests could receive 406 instead of the auth failure).

(b) NEW `lib/xaas_web/plugs/a2a_parse_floor.ex`, plugged in endpoint.ex BEFORE
`Plug.Parsers` for /a2a POSTs. Decodes valid JSON and passes it downstream;
on malformed JSON answers a dep-shaped -32700 (HTTP 200, id null). The pinned
dependency's parse classification was verified correct.

## New courts

- v1_protocol_test case 4b (malformed-JSON parse floor)
- ggen_workbench_auth_floor_test (auth ordering on /api/workbench)

## Verification (lane-reported)

- a2a + workbench gate set: 8 passed
- plugs: 13 passed
- web suite: 350/351

## Standing

PARTIAL_ALIVE — one web-suite failure remains (350/351), reported as-is.
