# W984eq — XaasWeb controller residue probe (unclaimed-family)

Subject: /Users/sac/xaas @ feat/playwright-surface (HEAD 32b72c4f at probe start).
Lane: W984eq. No commit (per lane contract). Build root `_build-laneW984eq`.

## Method
CamelCase `defmodule` grep of each controller module name against `test/`;
route/path grep for indirect coverage; router read for pipelines/scopes;
residual branches courted through real ConnCase HTTP.

## Per-module disposition

| Module | File | Test refs | Disposition |
|---|---|---|---|
| XaasWeb.AshTypescriptRpcController | ash_typescript_rpc_controller.ex | 0 direct; route-hit | COVERED (indirect) — `test/xaas_web/rpc_surface_deepening_test.exs` drives `/internal-api/rpc/run` + `/rpc/validate` via real HTTP |
| XaasWeb.CapabilityRegressionsController | capability_regressions_controller.ex | 1 | COVERED — `capability_regressions_controller_test.exs` |
| XaasWeb.ErrorHTML | error_html.ex | 0 direct | COVERED (indirect) — 404 HTML render exercised by p4 of the new court |
| XaasWeb.ErrorJSON | error_json.ex | 0 | COVERED by new court (p3, p5) — was the only fully uncovered renderer |
| XaasWeb.EuAiActExportController | eu_ai_act_export_controller.ex | 2 | COVERED |
| XaasWeb.ExecutionFabricController | execution_fabric_controller.ex | 7 | COVERED |
| XaasWeb.FabricController | fabric_controller.ex | 1 | COVERED — `fabric_controller_test.exs` |
| XaasWeb.GgenWorkbenchController | ggen_workbench_controller REFUSED/502/503/422 branches | 0 direct | COVERED (indirect) — `test/xaas/workbench_deepening_test.exs` drives every branch (200/422 REFUSED/502 BLOCKED/503) via real HTTP + real Bandit worker |
| XaasWeb.HealthController | health_controller.ex | 2 | COVERED — `health_controller_test.exs` + platform route deepening |
| XaasWeb.OcelSummaryController | ocel_summary_controller.ex | 2 | COVERED |
| XaasWeb.PageController | page_controller.ex | 1 | COVERED — `page_controller_test.exs` (single :home action) |
| XaasWeb.PrometheusQueryAllowlist | prometheus_query_allowlist.ex | 0 direct | COVERED (indirect, now exhaustive on the HTTP path) — subquery branch was the one unexercised allowlist clause; now courted via controller HTTP (p2) |
| XaasWeb.PrometheusQueryController | prometheus_query_controller.ex | 1 file | COVERED after new court — `missing_query_param` clause (query/2 second head) had zero exercise; now pinned (p1). `{:error, other}` non-TransportError 502 clause remains UNCOVERED (not reachable via real HTTP without faking Req; disclosed, not courted) |
| XaasWeb.StripeWebhookController | stripe_webhook_controller.ex | 3 | COVERED |
| XaasWeb.WdFaContextController | wd_fa_context_controller.ex | 1 | COVERED — `wd_fa_context_controller_test.exs` |
| XaasWeb.WdFaStogafController | wd_fa_stogaf_ex | 1 | COVERED — `wd_typo` note: file is `wd_fa_stogaf_controller.ex`, test `wd_fa_stogaf_controller_test.exs` |

## New court
`test/xaas_web/controllers/residue_court_w984eq_test.exs` — 5 tests, real
ConnCase through the real router, real INTERNAL_API_TOKEN from
test_helper.exs, zero mocks.

- p1 missing `query` param → 400 `missing_query_param` (mutation: delete
  the clause head → 500 FunctionClauseError)
- p2 subquery PromQL `[5m:1m]` → 400 `query_not_allowed` "subquery syntax"
  (mutation: drop `reject_subquery/1` → forwards to unreachable Prometheus
  → 502 prometheus_unreachable; the real closed-port 502 is load-bearing)
- p3 unmatched route with `accept: application/json` → 404 via
  XaasWeb.ErrorJSON (`errors.detail == "Not Found"`)
- p4 unmatched browser route → 404 text/html via ErrorHTML
- p5 direct ErrorJSON.render/2 template→status-message mapping

## Probe findings (real, observed)
1. `/internal-api` unmatched paths: the token floor still applies — an
   unauthenticated 404 probe gets 401 before route matching surface
   (auth-before-enumeration, good). Court p3 initially failed on this.
2. `/internal-api` 404s render as JSON:API `no_route_found` error objects
   (AshJsonApi error view), NOT XaasWeb.ErrorJSON — ErrorJSON only renders
   on the top-level endpoint path with plain JSON accept. Both facts
   observed by running the request, not by reading.
3. Content negotiation: internal_api pipeline accepts only `json-api`;
   sending `application/json` to it → Phoenix.NotAcceptableError 406.

## Gates
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984eq \
  mix test test/xaas_web/controllers/residue_court_w984eq_test.exs
=> Result: 5 passed   exit 0
Mock gate scan_mock_usage(["test","lib"]) => []
```
Pre-existing 404s into `XaasWeb.ErrorJSON`/`ErrorHTML` before this court:
none named either module (grep). Grafana/PromEx uploader warnings during
test boot are pre-existing environment noise, unrelated.

## Cleanup
Lane build root removed after gates: `rm -rf _build-laneW984eq` exit 0,
directory confirmed gone (`ls` → No such file or directory).
