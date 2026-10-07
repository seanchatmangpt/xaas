# X3 — xaas web surface audit (v26.10.5)

Lane X3, read-only inventory, 2026-10-06. Subject: `feat/playwright-surface` @ `d1db2b03`.
All paths absolute under `/Users/sac/xaas`.

## 1. LiveView inventory (lib/xaas_web/live)

| module | file | route (router.ex) | pipeline | playwright-tested today |
|---|---|---|---|---|
| XaasWeb.NextRead.ReaderLive | lib/xaas_web/live/next_read/reader_live.ex | `live "/next-read"` | :browser | yes — e2e/next-read-ml.spec.cjs (deep) |
| XaasWeb.WdFa.CaseStudyLive | lib/xaas_web/live/wd_fa/case_study_live.ex | `live "/case-studies/wd-fa"` | :browser | yes — e2e/wd-fa-cs2.spec.cjs (deep) |
| XaasWeb.Chicago.DrillDownLive | lib/xaas_web/live/chicago/drill_down_live.ex | `live "/chicago"` | :browser | render-only (e2e/full_surface.spec.ts) |
| XaasWeb.Chicago.SellerLive | lib/xaas_web/live/chicago/seller_live.ex | `live "/chicago/seller"` | :browser | render-only (full_surface) |
| XaasWeb.MarketplacePplanExplorerLive | lib/xaas_web/live/marketplace_pplan_explorer_live.ex | `live "/marketplace-pplan"` | :browser | render-only (full_surface) |
| XaasWeb.MarketplaceCatalogLive | lib/xaas_web/live/marketplace_catalog_live.ex | `live "/marketplace-catalog"` | :browser | yes — e2e/marketplace.spec.ts (PW3) + full_surface journey |
| XaasWeb.System.CommandCenterLive | lib/xaas_web/live/system/command_center_live.ex | `live "/system"` (dev_routes-gated; 404 in prod, router.ex:290-294) | :browser (dev) | render-only (full_surface under dev routes) |
| XaasWeb.AutofdeLab.StatusLive | lib/xaas_web/live/autofde_lab/status_live.ex | `live "/dev/dashboards/autofde-lab"` (dev_routes-gated, router.ex:284) | :browser (dev) | NO — zero spec coverage |

8 LiveViews total; 3 deep-tested, 4 render-only, 1 completely untested (autofde-lab).

## 1b. Browser-reachable controllers

- `get "/"` → PageController :home — covered by e2e/smoke.spec.cjs
- `get "/case-studies/wd-fa/stogaf.json"` (router.ex:59) → WdFaStogafController — no direct spec
- `get "/case-studies/wd-fa/context/:case_id"` (router.ex:60) → WdFaContextController — no direct spec
- The two wd-fa JSON endpoints are fetched by the LiveView; a direct JSON court spec is a cheap add.

## 2. Playwright state (`/Users/sac/xaas/playwright.config.cjs`)

- testDir `./e2e`, baseURL `http://localhost:4000`, webServer `mix phx.server`
  (reuseExistingServer: true, timeout 120s). Real running server, no mocks.
- 7 spec files in `/Users/sac/xaas/e2e/`: smoke.spec.cjs, full_surface.spec.ts (PW8),
  marketplace.spec.ts (PW3), next-read-ml.spec.cjs, wd-fa-cs2.spec.cjs,
  ash-admin-state-change.spec.js, ash-admin-destroy.spec.js.
- full_surface.spec.ts BROWSER_SURFACES list (lines 34-43) enumerates exactly 8 surfaces:
  `/`, `/next-read`, `/case-studies/wd-fa`,
  `/chicago`, `/chicago/seller`, `/marketplace-pplan`, `/marketplace-catalog`, `/system`.
  Render-only for 5 of 8; deep journeys only for marketplace-catalog, next-read, wd-fa.
- The two ash-admin specs already prove REAL state change through the UI (create + destroy
  of a real CapabilityLivenessReceipt row in real Postgres via ash_admin panels) — the
  pattern for new deep specs exists and is Chicago-compliant.

## 3. Fleet-project surfaces in the web layer

HTTP exposure per fleet project, from real router.ex:

| fleet project | HTTP surface | route(s) | browser-visible / playwright-testable |
|---|---|---|---|
| ggen-marketplace | MarketplaceCatalogLive | `/marketplace-catalog` | YES — deep-covered (PW3/PW8) |
| ash_pplan | MarketplacePplanExplorerLive | `/marketplace-pplan` | render-only; no data-asserting spec |
| ash_a2a | /a2a scope (ZoeEventPlug + A2A.Plug) | `/a2a/zoe-event`, `/a2a/` | NO — token-gated JSON, no browser surface |
| ash_a2a (MCP) | /mcp scope (AshAi.Mcp.Router via XaasWeb.McpScope.mount) | `/mcp` | NO — token-gated JSON |
| ggen / ggen_igniter | GgenWorkbenchController | `/api/workbench/ggen/health`, `/api/workbench/ggen` | NO — token-gated JSON |
| ggen / ggen_igniter / ash typescript | AshTypescriptRpcController | `/internal-api/rpc/run`, `/internal-api/rpc/validate` | NO — token-gated JSON |
| execution fabric (autofde lineage) | ExecutionFabricController + FabricController | `/internal-api/execution/*`, `/internal-api/fabric/*` | NO — token-gated JSON |
| beam4pm / wasm4pm (OCEL) | OcelSummaryController | `GET /internal-api/ocel_summary` | NO — token-gated JSON |
| autofde-lab | XaasWeb.AutofdeLab.StatusLive | dev-only `/dev/dashboards/autofde-lab` | surface exists; NO spec at all |
| ferroplan | none | — | NO web exposure |
| zcode-cli | none | — | NO web exposure |
| gymact | none | — | NO web exposure |
| witness (PW5, Xaas.Witness) | NONE | — | zero HTTP/UI exposure — largest single gap |

Real-output basis for the witness gap: `grep -rn "Witness" lib/xaas_web` → no hits in the
web layer; `grep -rln "Witness" lib/xaas` → lib/xaas/witness.ex,
lib/xaas/witness/{certified_receipt,catalog,verification_key}.ex, lib/xaas/semantics/vkg.ex.
The domain exists (commit 3508f427) with zero routes in lib/xaas_web.

## 4. Gap plan — routes/LiveViews needed for playwright-validation at v26.10.5

Ranked by (fleet-wiring value)/(effort). Per _LANES.md the coordinator owns router.ex; lanes
submit exact lines. New LiveViews/controllers are lane work under lib/xaas_web.

1. **Witness certified-receipt viewer** (largest gap; PW5 domain, zero exposure):
   - `live "/witness", XaasWeb.Witness.ReceiptsLive` (:browser pipeline, read-only)
   - table of certified receipts (subject SHA, standing, verification-key id, timestamp);
     row detail via `handle_params` (`?id=` or `live "/witness/receipts/:id"`).
   - Ash policy floor: deny-by-default + scoped `bypass` read carve-out on CertifiedReceipt
     (per xaas CLAUDE.md). Auth posture (dev-routes gate vs session auth) = coordinator decision.
   - Spec: e2e/witness.spec.cjs — render + row detail + real-data assertion, seeding one real
     receipt through the domain's existing lawful write path.

2. **/fleet read-only proxy scope** — one thin LiveView per fleet project, each fetching real
   data server-side and rendering it for browser validation:
   - `live "/fleet/a2a-agent-card", XaasWeb.Fleet.A2aAgentCardLive` — renders the real `/a2a`
     agent card JSON (ash_a2a, R4's deliverable) as a browser-visible page.
   - `live "/fleet/execution-receipts", XaasWeb.Fleet.ExecutionReceiptsLive` — browser render of
     ExecutionFabric/Fabric receipts (autofde lineage, R8/R11).
   - `live "/fleet/ocel", XaasWeb.Fleet.OcelLive` — browser render of OcelSummary data
     (beam4pm/wasm4pm, R9/R10).
   - `live "/fleet/ggen-workbench", XaasWeb.Fleet.GgenWorkbenchLive` — workbench health/run view
     (ggen/ggen_igniter, R1/R3).
   - `/fleet/*` auth posture = coordinator admission decision (browser pages cannot carry the
     bearer token; options: dev-routes gate, session auth, or deny-by-default + read carve-out).
   - No fleet LiveView proposed for ferroplan / zcode-cli / gymact — no natural read-only render
     surface yet; ferroplan plans could become `/fleet/plans` if R6 delivers wiring.

3. **Deep specs for render-only surfaces** (cheapest validation gains):
   - e2e/system-command-center.spec.cjs: `/system` beyond render-only (tab/refresh interaction +
     real observation-data assertion). Promotion out of dev-routes is a coordinator decision;
     either way the spec should exist.
   - e2e/marketplace-pplan.spec.cjs: search/filter interaction + real plan-data assertion —
     doubles as ash_pplan fleet wiring proof (R5's falsifier).
   - e2e/chicago.spec.cjs: drill-down interaction (drill into a node, assert data update).

4. **autofde-lab spec** (cheapest gap close; surface exists, only a spec is missing):
   e2e/autofde-lab.spec.cjs against dev-routes-enabled server — render + real status assertion.

5. **wd-fa JSON court specs**: direct fetch assertions on `/case-studies/wd-fa/stogaf.json` and
   `/case-studies/wd-fa/context/:case_id` (Playwright `request` fixture) — cheap, covers the
   two uncovered controllers.

## 5. Route lines to submit to coordinator (exact)

```elixir
# X3-submitted seam lines (coordinator applies; per _LANES.md lanes never edit router.ex)
live("/witness", XaasWeb.Witness.ReceiptsLive)
live("/fleet/a2a-agent-card", XaasWeb.Fleet.A2aAgentCardLive)
live("/fleet/execution-receipts", XaasWeb.Fleet.ExecutionReceiptsLive)
live("/fleet/ocel", XaasWeb.Fleet.OcelLive)
live("/fleet/ggen-workbench", XaasWeb.Fleet.GgenWorkbenchLive)
```

## 6. Falsifiers

- "every fleet project is playwright-validated at v26.10.5" is falsified if any of: the witness
  viewer never lands, `/system` remains render-only, autofde-lab keeps zero specs, no /fleet/*
  scope lands, or ferroplan / zcode-cli / gymact / beam4pm / wasm4pm have neither a
  browser-visible proxy nor an explicit REFUSED/BLOCKED receipt.
- "every browser surface is spec-covered" is falsified while `/dev/dashboards/autofde-lab`
  has no spec.
- Render-only coverage does not equal playwright-validation of fleet wiring (render-only is
  not data-asserting); PW8 is render-only for 5 of its 8 surfaces.

## 7. Standing

All §4-5 proposals are UNKNOWN — none executed; this is inventory + gap plan, not a receipt.
Observed facts (router.ex read; e2e/ listing; spec-head reads; grep output on Witness/Pplan/
Ferroplan exposure) are O*. Path to ALIVE: coordinator admits route lines → lane implements
LiveViews + specs → `npx playwright test` on a real `mix phx.server` → receipts.
