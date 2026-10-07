# X1 — Playwright Surface Inventory & Spec Gap Plan (xaas v26.10.5)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface` @ `d1db2b03`. Read-only sweep of `playwright.config.cjs`, `package.json`, all specs under `e2e/`, and `lib/xaas_web/router.ex` (read in full). All paths verified on disk this session.

## 1. Harness — how tests run, what env they need

- Deps: `@playwright/test ^1.62.1` (`package.json`); script `test:e2e = "playwright test"`.
- Config: `/Users/sac/xaas/playwright.config.cjs` — `testDir: "./e2e"`, timeout 30s, `webServer: { command: "mix phx.server", port 4000, reuseExistingServer: true, timeout: 120_000 }`, `baseURL: process.env.PLAYWRIGHT_BASE_URL || "http://localhost:4000"`.
- Server start, two lawful paths:
  1. Playwright boots it: runs `mix phx.server` (120s boot window), reuses an already-listening :4000 (`reuseExistingServer: true`).
  2. External boot first, per `/Users/sac/xaas/CLAUDE.md`: `MIX_ENV=dev INTERNAL_API_TOKEN=<real-token> mix phx.server`, then `npx playwright test`.
- Env:
  - `INTERNAL_API_TOKEN` — `XaasWeb.Plugs.RequireInternalApiToken` gates `/internal-api`, `/api`, `/mcp`, `/a2a`, `/api/workbench`; fails closed when absent. Not needed for the 7 existing specs (all browser-only) but required for every new API spec below.
  - `PLAYWRIGHT_BASE_URL` (optional) — overrides `http://localhost:4000`.
  - `A2A_BASE_URL` (optional) — router default `http://localhost:4000/a2a` (`router.ex:203,208`).
  - Toolchain: asdf shims first — `PATH=$HOME/.asdf/shims:$PATH` (Homebrew elixir 1.19.5 shadows the pinned 1.20.2-otp-28); `MIX_ENV=test` preferred per the no-dev-compile-during-campaign memory note. Postgres: local `postgresql@14`, db `xaas_dev` on :5432 must be up.
- Marketplace catalog seeding: `MarketplaceCatalogLive` ingests `Application.get_env(:xaas, :marketplace_catalog_source)` at mount (`lib/xaas_web/live/marketplace_catalog_live.ex:15,48`). The real-catalog path (documented in `e2e/marketplace.spec.ts` / `full_surface.spec.ts` docstrings): generate catalog JSON via `python3 scripts/marketplace.py catalog` in `/Users/sac/ggen-marketplace`, write to a temp file, and boot the server with `Application.put_env(:xaas, :marketplace_catalog_source, <file>)` before endpoint boot. Without seeding, the marketplace "real packs" courts fail even though the page renders.

## 2. Existing Playwright coverage (testDir `./e2e` — only directory scanned)

7 spec files, all under `/Users/sac/xaas/e2e/`:

| Spec | Covers | Route(s) |
|---|---|---|
| `e2e/smoke.spec.cjs` | root renders: title present, non-empty body | `/` |
| `e2e/full_surface.spec.ts` (PW8) | all 8 browser surfaces render — HTTP<400, LiveView `phx-connected` over websocket, no "Something went wrong"/RuntimeError, non-empty body; marketplace catalog courts: `h1` = "Marketplace Catalog", `#pack-table` visible, `pack-row-*` count > 0 with name/version/digest cells, `#catalog-summary` "N packs in the catalog"; further catalog journey tests in the file tail | `/`, `/next-read`, `/case-studies/wd-fa`, `/chicago`, `/chicago/seller`, `/marketplace-pplan`, `/marketplace-catalog`, `/system` |
| `e2e/marketplace.spec.ts` (PW3) | catalog over real seeded catalog: table renders, search "aaif" narrows to real pack(s), rendered pack count equals ingested catalog count, pack detail fields (name/version/digest) render | `/marketplace-catalog` |
| `e2e/ash-admin-state-change.spec.js` | ash_admin creates a real `CapabilityLivenessReceipt` via the admin `:ingest` form under the "pause authorization" toggle; row persists in real Postgres | `/admin/?domain=Operations&resource=CapabilityLivenessReceipt` |
| `e2e/ash-admin-destroy.spec.js` | ash_admin destroys a real `CapabilityLivenessReceipt` via the real destroy-confirmation URL; row genuinely gone from Postgres | `/admin/?domain=...&action_type=destroy...` |
| `e2e/next-read-ml.spec.cjs` | dual-persona Next Read, explainability drawer, live pin/unpin curation, desk metrics, "Ask the Catalog" | `/next-read` |
| `e2e/wd-fa-cs2.spec.cjs` | WD-FA case study: KNOWN/PARTIAL/UNKNOWN classification, MachineExperience replay without an LLM, 7/7 controls, delta before/after, context JSON fetched via `page.request.get` | `/case-studies/wd-fa` + context JSON route |

Adjacent Playwright configs exist but are out of scope of `npx playwright test` from root: `deps/ex4pm/playwright.config.ts` + `deps/ex4pm/tests/e2e/*.spec.ts`, and `test/bdd/next_read.spec.ts` (vitest-cucumber, not Playwright).

## 3. Gap matrix — fleet-project surfaces with zero Playwright coverage

All browser (`:browser` pipeline) surfaces have at least render coverage via PW8. Everything token-gated is a JSON/API surface; "playwright coverage" there means request-level specs (`page.request` / `request.new_context` with `Authorization: Bearer ${process.env.INTERNAL_API_TOKEN}`). None exist — zero request-level coverage repo-wide.

| Surface | Router locus (`lib/xaas_web/router.ex`) | Gap |
|---|---|---|
| `/internal-api/health`, `/capability_liveness_regressions`, `/ocel_summary`, `/prometheus/query`, `/rpc/run`, `/rpc/validate` | :87–120 | no spec |
| `/internal-api/execution/*` (`hooks/:event`, `mcp`, `runs`, `epochs/:epoch_id/receipts`) | :101–119 | no spec |
| `/internal-api/fabric/*` (`probe`, `admit`, `runs`, `receipts`, `actuate` → typed 403 `REFUSED(authority_ceiling:actuate)` — the 403 is itself a court) | :126–134 | no spec |
| `/internal-api/sparql` (Ontop proxy) | :231–235 | no spec |
| `/api` forward → `XaasWeb.ApiRouter` | :262 | no spec |
| `/api/workbench/ggen/*` (health + run) | :217–222 | no spec — the ggen workbench surface has zero coverage |
| `/mcp` (AshAi MCP mount, audit plug) | :175–184 | no spec |
| `/a2a` (`/a2a/zoe-event` + A2A.Plug NextReadUserAgent) | :195–210 | no spec — the a2a surface has zero coverage |
| `/webhooks/stripe` (signature verification) | :72–76 | no spec |
| `/admin` deep matrix beyond the single-resource create/destroy pair (other domains/resources) | :302–306 | partial (2 specs, 1 resource) |
| `/dev/dashboard` (LiveDashboard), `/dev/mailbox`, `/dev/dashboards/autofde-lab` | :279–285 | no spec |
| `/chicago`, `/chicago/seller`, `/marketplace-pplan`, `/system` | :53–65, :293 | render-only (PW8); no interaction courts like marketplace/next-read/wd-fa have |

## 4. Gap plan — exact new spec files to claim "validated against playwright at v26.10.5 feature complete"

New files, all in `/Users/sac/xaas/e2e/` (the only scanned testDir). Courts (b)–(f) need `INTERNAL_API_TOKEN` in env; court (a) of each file asserts the 401 fail-closed path with no token, which is itself a named repo discipline (`/Users/sa/xaas/CLAUDE.md` API auth floor).

1. `e2e/internal-api.spec.ts` — bearer 401-without / 200-with; GET `/internal-api/health`, `/ocel_summary`, `/capability_liveness_regressions`; POST `/rpc/validate` round trip. Cheapest first spec.
2. `e2e/execution-fabric.spec.ts` — POST `/internal-api/execution/runs` happy path (real Run created, receipt readable at GET `/internal-api/execution/epochs/:id/receipts`); POST `/internal-api/fabric/actuate` → non-2xx with typed `authority_ceiling:actuate` refusal body; `/internal-api/fabric/probe` 200.
3. `e2e/mcp-a2a.spec.ts` — `/mcp` tool list over JSON-RPC with bearer; `/a2a` agent card / message round trip (A2A.Plug); `/a2a/zoe-event` accepted-event court.
4. `e2e/ggen-workbench.spec.ts` — GET `/api/workbench/ggen/health` 200 with bearer; POST `/api/workbench/ggen` bounded-bundle run (or typed refusal when the Fly worker is absent — assert the typed body, never silence); the ggen lane surface's falsifier.
5. `e2e/sparql-proxy.spec.ts` — GET `/internal-api/sparql` with bearer: 200 when Ontop is up; typed non-200 degradation court when it is not (assert typed, not silence).
6. `e2e/stripe-webhook.spec.ts` — POST `/webhooks/stripe` with an invalid signature → non-2xx (authenticity gate); no row created. Public endpoint, no bearer needed.
7. `e2e/ash-admin-matrix.spec.ts` — walk ≥3 additional domains/resources through `/admin` (list + read panels; state-change only where a safe probe resource exists, reusing the proven `CapabilityLivenessReceipt` pattern).
8. `e2e/dev-routes.spec.ts` — `/dev/dashboard`, `/dev/mailbox`, `/dev/dashboards/autofde-lab` render (dev_routes enabled in dev/test configs: `config/dev.exs:106`, `config/test.exs:70`).
9. `e2e/chicago.spec.ts` + `e2e/marketplace-pplan.spec.ts` — interaction courts for the four render-only browser surfaces (`/chicago`, `/chicago/seller`, `/marketplace-pplan`, `/system`), matching the depth marketplace/next-read/wd-fa already have.

### Acceptance gate

Feature-complete claim = all 9 spec files exist under `e2e/` and a full `npx playwright test` run passes against a dev server booted with `INTERNAL_API_TOKEN` set and the real marketplace catalog seeded. Verification ladder per `/Users/sac/xaas/CLAUDE.md`: `npm run test:e2e` real output reported, red results disclosed not hidden.

Standing: UNKNOWN until the specs are written and a real `npx playwright test` run passes on this branch. This file is the lane X1 plan; execution is a separate lane.
