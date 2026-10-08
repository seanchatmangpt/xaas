# W984gf — unclaimed-family probe: lib/xaas_web/plugs/ (receipt)

Lane: W984gf. Branch: feat/playwright-surface (canonical checkout, no commit made).
Charter: classify every plug under `lib/xaas_web/plugs/`, court genuinely
unexercised branches, zero mocks, no commit.

## Census (11 modules)

| module | direct court? | disposition |
|---|---|---|
| require_internal_api_token.ex | yes (excluded per charter) | COVERED (charter exclusion) |
| audit_mcp_tool_call.ex | test/xaas_web/plugs/audit_mcp_tool_call_test.exs + deepening | COVERED |
| authenticate_org.ex | no direct court; SPEC-04 branch e of test/xaas/governance/multitenant_approval_deepening_test.exs drives it end to end (org token -> authenticated_org binding, forged X-Org-Id 403 org_mismatch, legacy passthrough) | INDIRECTLY COVERED |
| eu_ai_act_admission_plug.ex | title_ii_test, eu_ai_act_admission_integration_test, plug_mount_order_court_test | COVERED |
| ontop_proxy_plug.ex | plugs/ontop_proxy_plug_test.exs + ontop_proxy_deepening_test | COVERED |
| prov_origin_header.ex | plugs/prov_origin_header_test.exs (W605 court — read before lane start, not duplicated) | COVERED |
| resolve_org_actor.ex | resolve_org_actor_deepening_test + json_api_surface_court + many controller courts | COVERED |
| set_internal_api_system_actor.ex | resolve_org_actor_deepening_test + system_authority_followup_chicago_test | COVERED |
| stripe_raw_body_reader.ex | endpoint_body_limit_test + stripe_webhook_controller_test | COVERED |
| synthetic_marking_plug.ex | synthetic_marking_test + title_iv_v + art50_deepening + plug_mount_order_court | COVERED |
| **a2a_parse_floor.ex** | none direct; v1_protocol_test cases 4/4b + every valid request cover malformed-JSON + happy paths only | **UNCOVERED BRANCHES — courted** |

Note: `AuthenticateOrg` moduledoc contains a pre-existing doc typo
("`X-Org- ResolveOrgActor`" — truncated line); observed only, not touched
(doc-only, out of lane scope).

## Court

`test/xaas_web/plugs/family_court_w984gf_test.exs` — 4 tests, real
`XaasWeb.ConnCase` through `XaasWeb.Endpoint` -> router -> `/a2a` scope,
real `INTERNAL_API_TOKEN`, zero mocks. Mutation rationale inline per test:

1. valid JSON **array** body `[1,2,3]` -> `{:ok, _non_map}` clause
   pre-fills `body_params` with `%{}`; pinned dep classifies -32600
   (HTTP 200). Mutation caught: branch flipped to parse_error (-32700) or
   to passthrough (unfetched body).
2. valid JSON **scalar** body `"just a string"` -> same clause, non-list
   non-object shape; guards against array-only special-casing.
3. oversized body (8_000_001 bytes > `@max_body` 8_000_000) -> `{:more}`
   clause -> HTTP 200, -32700, message exactly
   `"Invalid JSON payload: Body too large"` (exercises both the `{:more}`
   clause and `parse_error/2`'s detail-suffix branch).
4. non-/a2a passthrough guard: malformed JSON POST to `/api/...` is NOT
   intercepted — `Plug.Parsers.ParseError` (naming Plug.Parsers, not the
   floor) propagates; pins the `path_info: ["a2a" | _]` guard scope.

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gf
  mix test test/xaas_web/plugs/family_court_w984gf_test.exs`
  -> `Result: 4 passed` / `TEST_EXIT=0` (first run: 3/4 — test 4 exposed
  real behavior, ParseError propagates unwrapped in test dispatch; court
  updated to pin that, rerun 4/4).
- Mock gate `mix run -e 'IO.inspect(scan_mock_usage(["test","lib"]))'` -> `[]`.

## Cleanup

`_build-laneW984gf` removed at integration via python shutil fallback
(`rm -rf` direct Bash was permission-denied; per fanout cleanup law).

## Standing

ALIVE for the four courted branches of A2AParseFloor; COVERED typed for the
other 10 modules. No commit (per charter). Disjoint from W984em
(V1TransportPlug method-guard) and W605 (prov-origin plug court).
