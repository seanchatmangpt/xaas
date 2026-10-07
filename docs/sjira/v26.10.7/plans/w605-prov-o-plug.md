# W605 — ProvOriginHeader plug (WP-1, OS-16 / EU AI Act Art. 50(2))

Lane W605, v26.10.7 campaign. Branch `feat/playwright-surface` (shared canonical
checkout, no commit made per dispatch).

## Header shape (pinned, one machine-detectable form)

```
x-prov-o: wasGeneratedBy=<https://w3id.org/xaas/agent/xaas-platform>; actedOnBehalfOf=<https://w3id.org/xaas/operator/xaas-operators>
```

- Terms `wasGeneratedBy` / `actedOnBehalfOf` are W3C PROV-O object properties,
  namespace `http://www.w3.org/ns/prov#` (PROV-O W3C Recommendation 2013-04-30,
  https://www.w3.org/TR/prov-o/). IRIs angle-bracketed per PROV-N.
- Values are constant, config-driven application identity:
  `Application.get_env(:xaas, :prov_origin, [])` keys `:agent_iri` /
  `:operator_iri`, compile-time constants as fallback. Never per-request
  fabricated. Assertion = "this response is machine-generated".

## Files

- `lib/xaas_web/plugs/prov_origin_header.ex` — NEW plug. `register_before_send`
  so refusal envelopes are marked; values via `header_value/0` (public, courted).
- `lib/xaas_web/router.ex` — minimal diff: new `pipeline :prov_origin`; added to
  `/a2a` scope pipe_through (FIRST, before the token floor — before_send must
  survive the halt) and to the `/api` forward scope pipe_through (first).
- `test/xaas_web/prov_origin_header_test.exs` — NEW Chicago court (ConnCase,
  real endpoint pipeline, no mocks). 5 courts.

## Surfaces wired

- `/a2a` (ZoeEventPlug, V1TransportPlug, A2A.Plug forwards) — via scope
  `pipe_through([:prov_origin, :api, :require_internal_api_token])`.
- `/api` (forward to `XaasWeb.ApiRouter` with the full internal-api stack).
- `/internal-api` direct scopes: NOT wired (dispatch named /api + /a2a only).
- LiveView/`:browser`: clean pipeline hook EXISTS (`pipeline :browser`), but
  NOT wired — disclosed: wiring it would attach the assertion "machine-
  generated" to human-facing pages, a false provenance claim.

## Standing

**ALIVE (lane-local, uncommitted).** Courts GREEN ×3, mutation RED witnessed.

Commands (all under `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
MIX_BUILD_ROOT=_build-laneW605`):

```
mix test test/xaas_web/prov_origin_header_test.exs
# run 1 (fresh lane build root, full compile):  5 passed, exit 0
# run 2 (determinism):                          5 passed
# MUTATION (plug dropped from :prov_origin):    2/5 passed, 3 failed —
#   courts 1 (/a2a), 2 (/api), 3 (constancy) RED; precision pin (4) and
#   plug-level isolation (5) GREEN, exactly the expected sensitivity
# post-revert:                                  5 passed
```

Receipt fields: subject = working tree of `feat/playwright-surface` at
bbaaeec6 (no commit made, per dispatch); verification ladder = unit/endpoint
court (real endpoint pipeline, real responses, no mocks) + mutation court;
falsifier = drop-plug mutation (witnessed RED, then reverted); replay =
`mix test test/xaas_web/prov_origin_header_test.exs` under the env above.
Standing is lane-local until the coordinator integrates and commits.

## Notes / disclosures

- `_build-laneW605` left on disk for the coordinator (lane-lease cleanup was
  permission-denied in this session); delete at integration per the fanout
  cleanup law.
- `router.ex` is a shared hot file: diff is +13/-1, three touch points only
  (new `pipeline :prov_origin`, `/a2a` pipe_through, `/api` forward-scope
  pipe_through). Mid-lane the file changed on disk once (another lane);
  my three edits were re-anchored against fresh reads and the final diff
  contains only the W605 wiring.
- Config keys `:xaas, :prov_origin` (`:agent_iri`, `:operator_iri`) are
  read at send time with compile-time constant fallbacks; no config file
  was edited (zero-config defaults are the shipped identity).
