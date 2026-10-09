# W984hq — Router/Endpoint plug-chain unclaimed-family probe

Lane: W984hq · checkout `/Users/sac/xaas` @ `feat/playwright-surface` (16a7bfa5, no commit made)
Subjects: `lib/xaas_web/router.ex` (sibling-modified, READ ONLY — untouched),
`lib/xaas_web/endpoint.ex`, `lib/xaas_web/telemetry.ex`.
Court file: `test/xaas_web/router_chain_court_w984hq_test.exs` — 6 tests, real ConnCase
through the real endpoint, real `INTERNAL_API_TOKEN` bearer convention, zero mocks.

## Per-scope / pipeline disposition

| Router surface | Pipeline(s) | Disposition | Evidence |
|---|---|---|---|
| `scope "/"` :browser (GET /, lives) | browser | **PARTIALLY covered -> covered**: happy path `page_controller_test`; negotiation/headers/HEAD newly courted | court cells a-c |
| :browser `plug(:accepts, ["html"])` | browser | **uncovered -> covered** | JSON-Accept GET / -> 406 (Phoenix.NotAcceptableError) |
| :browser `put_secure_browser_headers` | browser | **uncovered -> covered** | x-frame-options present, x-content-type-options=nosniff on GET / |
| endpoint `plug(Plug.Head)` | endpoint | **uncovered -> covered** | HEAD / -> 200 (HEAD->GET rewrite; removing the plug = no-route error) |
| `scope /webhooks` POST stripe | :api | **negotiation cell uncovered -> covered**; signature checks deeply covered by `stripe_webhook_deepening_test` | html-Accept POST -> 406; default-Accept reaches controller (400/500, not 404/406) |
| `/internal-api` catch-all forward scope | token floor -> :internal_api(json-api) -> system actor | **covered** (W739 unauth cells `jsonapi_content_negotiation_test`; authenticated 406 side newly courtered) | authed text/plain -> 406 |
| `/internal-api` explicit GET routes (health, capability regressions, ocel, eu-ai-act, prometheus, rpc, execution) | :api + token floor | **indirectly covered** by per-controller tests (`health_court_test`, `capability_regressions_controller_test`, `eu_ai_act_export_*`, `execution_fabric_*`, `rpc_surface_deepening`, `prometheus_query_controller_test`) | controller-level; not duplicated per lane charter |
| `/internal-api/fabric` scope | :api + token floor | **indirectly covered** (`fabric_controller_test`, `quiescent_fabric_tie_test`) | controller-level |
| `/internal-api/sparql` forward | :api + token floor | **covered** (`ontop_proxy_deepening_test`: auth'd + unauth'd, methods) | pre-existing |
| `/api/workbench` scope (W150 order) | token floor THEN :api | **covered** (`ggen_workbench_auth_floor_test` 4 cells, incl. W299c fall-through cell) | pre-existing |
| `/api` forward scope (W299c/W605 order) | prov_origin, floor, internal_api, authenticate_org, resolve_org_actor, system actor | **covered** (`jsonapi_content_negotiation_test` W739/W299c cells, `prov_origin_header_test` cell 2, `plug_mount_order_court_test`) | pre-existing |
| `/mcp` scope | :api, floor, resolve_org_actor (documented no-op), audit | **covered** (`family_court_w984gp_test.exs` incl. zero-audit-row-on-401; `plugs/audit_mcp_tool_call_test`) | pre-existing |
| `/a2a` scope | prov_origin, :api, floor; zoe-event, v1, catch-all forwards | **covered** (`a2a_v1_wire_deepening_test`, `a2a/v1_protocol_test`, `plug_mount_order_court_test` marking/refusal order, `prov_origin_header_test` cell 1, zoe tests) | pre-existing |
| dev-routes guarded scopes (/dev, /system, /admin) | browser | **COVERED-BY-CONSTRUCTION (compile-time)**: `Application.compile_env(:xaas, :dev_routes)` branch is resolved at router compile time, not dispatch time — not courtable via ConnCase; absence in prod is a config property, not a pipeline cell. Typed COVERED(config), no test added. | router.ex:339 |
| endpoint A2AParseFloor / SyntheticMarking / EuAiActAdmission / Plug.Parsers(StripeRawBodyReader) / body limits | endpoint | **covered** (`plug_mount_order_court_test`, `synthetic_marking_test`, `eu_ai_act_admission_integration_test`, `endpoint_body_limit_test`, `stripe_webhook_deepening_test` b1-b6) | pre-existing |
| LiveView socket `/live`, Plug.Static (/ash_surface, /) | endpoint | **indirectly covered** (browser tests serve static via Plug.Static; socket via LiveView test harness). No pipeline-level court added — static mount failure would fail every existing browser test. | pre-existing |
| `XaasWeb.Telemetry` | supervision | **COVERED (trivial)**: declarative metric list + stock supervisor; only runtime-reachable behavior is the poller child. No court added (no unclaimed branch). | telemetry.ex |

## Court additions (mutation rationale per test)

1. `a JSON-Accept GET / is refused 406` — kills "drop/swaps :accepts in :browser".
2. `GET / carries the secure browser headers` — kills "drop put_secure_browser_headers".
3. `HEAD / answers 200` — kills "remove endpoint Plug.Head".
4. `html-Accept POST /webhooks/stripe -> 406` — kills "drop :accepts from :api" (leak-free negotiation).
5. `default-Accept POST /webhooks/stripe dispatches (400/500, not 404/406)` — kills "wrong pipeline/scope registration for /webhooks".
6. `authenticated text/plain on /internal-api forward -> 406` — kills "reorder token floor after :internal_api" (W739 authenticated side).

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984hq mix test test/xaas_web/router_chain_court_w984hq_test.exs` -> **6 passed, exit 0** (cold lane build).
- Mock gate `scan_mock_usage(["test","lib"])` -> **[]**.
- `_build-laneW984hq` removed post-gates (`rm -rf` succeeded; no shutil fallback needed).

## Standing

ALIVE (court executed on real endpoint at this tree state). No commit made, per lane
contract. Router untouched (sibling-modified, read-only honored).
