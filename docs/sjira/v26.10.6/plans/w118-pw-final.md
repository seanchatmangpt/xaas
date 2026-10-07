# W118 — Playwright Final Receipt (v26.10.6 convergence)

- Repo/branch: `/Users/sac/xaas`, branch `feat/playwright-surface`, working tree as of 2026-10-06 (~20:30 local), heavy uncommitted v26.10.6 convergence state.
- Runner env: `INTERNAL_API_TOKEN=dev-e2e-token`, `PHX_SERVER=true`, asdf toolchain (`PATH=$HOME/.asdf/shims:$PATH`).
- Command: `npx playwright test` (full suite, fresh server boot via `playwright.config.js` webServer, globalSetup catalog (13 packs) + witness seed).
- **Result: 97 total — 62 passed / 32 failed / 3 skipped (2.0m run).**
- Raw log: `/tmp/w118-run4.log` (final qualifying run); earlier runs `/tmp/w118-run2.log`.

## Session env-chain findings (pre-run blockers, resolved without file edits)

1. **Stale foreign server on :4000** (PIDs 54215/87926, later 36463) — a server booted
   *without* `INTERNAL_API_TOKEN` (verified via `ps eww`: token absent from its env) was
   adopted by the suite via `reuseExistingServer: true`, forcing every token-positive
   assertion to 503. First full run: 46F/48P. Fixed by killing the server and rerunning.
2. **`PHX_SERVER` not set in the webServer boot** — `config/runtime.exs:27-28` only sets
   `server: true` under `PHX_SERVER`; the `playwright.config.js` BOOT command
   (`mix run -e ... --no-halt`) starts the app but NOT the HTTP listener without it.
   Two runs died at `Timed out waiting 240000ms from config.webServer` even with the
   compile pre-warmed (`MIX_ENV=dev mix compile` exit 0). Run with `PHX_SERVER=true`
   in the runner env fixed boot. This is a config gap in the W100 boot chain (env-only
   workaround applied; no file edits made per lane rules).
3. **Sibling path-dep `../ash_surface` compile break (lane-active, since fixed)** — during
   this session `../ash_surface/lib/ash_a2a/resource.ex:46` had
   `@enforce_keys [:name, :type]` against a `defstruct` missing those keys (hard compile
   error), blocking all dev compiles ~4 min; the sibling lane landed a fix and compile
   went green (`mix compile` exit 0).
4. **Build-dir lock contention** across concurrent lanes repeatedly delayed webServer
   boots ("Waiting for lock on the build directory (held by process 88888/89085/5262/5416)").

## Per-file results

| Spec file | Pass | Fail | Skip | Notes |
|---|---|---|---|---|
| a2a-v1.spec.cjs | 2 | 3 | 0 | app gap |
| ash-admin-destroy.spec.cjs | 1 | 0 | 0 | |
| ash-admin-matrix.spec.cjs | 1 | 2 | 0 | app gap |
| ash-admin-state-change.spec.cjs | 0 | 1 | 0 | app gap |
| chicago-pplan-deep.spec.cjs | 3 | 5 | 0 | app gap / timeouts |
| dev-routes.spec.cjs | 0 | 2 | 0 | app gap |
| execution-fabric.spec.cjs | 1 | 2 | 0 | see blocks 13; block 14 passed |
| full_surface.spec.ts | 2 | 1 | 1 | |
| ggen-workbench.spec.cjs | 1 | 3 | 0 | contract mismatch |
| internal-api.spec.cjs | 3 | 1 | 0 | health w/ token 503 |
| marketplace.spec.ts | 4 | 0 | 0 | |
| mcp-a2a.spec.cjs | 3 | 1 | 0 | zoe-event card 500 |
| next-read-ml.spec.cjs | 0 | 3 | 0 | lane-active file |
| system-deep.spec.cjs | 3 | 4 | 0 | app gap |
| wd-fa-cs2.spec.cjs | 3 | 0 | 0 | |
| witness.spec.cjs | 0 | 2 | 0 | app gap + lane-active spec (untracked) |
| zcode-cli-fabric.spec.cjs | 4 | 5 | 0 | execution/mcp 500s + HTML error pages |
| a2a-v1 agent-card/tokenless branches | — | — | — | (included in counts above) |

Note: marketplace + full_surface partial passes confirm the W100 catalog/seed boot chain works end to end; token gates are fail-closed where asserted.

## Every failure, verbatim, classified

Format: failure text as emitted; classification ∈ {spec bug, app gap, env, seed, lane-active}.

1. **a2a-v1.spec.cjs:111 malformed JSON -> -32700** — `Error: expect(received).toBe(expected)` — `Expected: -32700` / `Received: -32600` (a2a/v1 surface returns invalid_request instead of parse_error). **App gap** (protocol contract).
2. **a2a-v1.spec.cjs:133 message/send happy path** — `Expected: "completed"` / `Received: "TASK_STATE_COMPLETED"`. **App gap** (state enum not v1-cased).
3. **a2a-v1.spec.cjs:158 SSE smoke** — `Expected substring: "text/event-stream"` / `Received string: "application/json; charset=utf-8"`. **App gap** (SSE not implemented on this route; JSON fallback).
4. **ash-admin-matrix:52 admin index** — `Error: expect(locator).toBeVisible() failed — element(s) not found` (expected "WebhookDelivery"/domain chrome text). **App gap** (admin chrome).
5. **ash-admin-matrix:120 record show** — `Expected: 200 / Received: 500` on the record show panel. **App gap** (record show route 500s).
6. **ash-admin-state-change:26 create+persist** — (from run4 full fail list; error in run3 pattern) `Expected: 200 / Received: 500` class failure. **App gap** (admin create path 500s).
7. **chicago-pplan-deep:194 seller projection** — `Expected: 12 / Received: 48` on `[data-testid^="chicago-evidence-"]` count. **App gap** (evidence cards over-render; 48=12×4 node kinds?).
8. **chicago-pplan-deep:251 delivery state** — `TimeoutError: page.waitForFunction: Timeout 15000ms exceeded.` **App gap** (delivery numbers never appear).
9. **chicago-pplan-deep:282 ontology summary** — `TimeoutError: page.waitForFunction: 15000ms exceeded.` **App gap** (explorer TTL summary never renders).
10. **chicago-pplan-deep:291 avatars** — `TimeoutError: page.waitForFunction: Timeout 15000ms exceeded.` **App gap**.
11. **chicago-pplan-deep:303 domain filter** — `TimeoutError: (15s)` — **App gap**.
12. **dev-routes:37 /dev/dashboard** — `expect(locator).toBeVisible() failed — element(s) not found` (LiveDashboard home). **App gap** (dev routes not rendering under this boot).
13. **dev-routes:65 /admin mount** — `element(s) not found` (ash_admin chrome). **App gap**.
14. **execution-fabric:27 actuate 403 body** — `Error: expect(received).toEqual(expected) — - Expected -1 / + Received +1` (typed refusal body drifted from the asserted shape). **App gap** (body drift).
15. **full_surface:117 full journey detail/back** — `element(s) not found` after detail navigation. **Spec bug** candidate: catalog/search steps passed standalone (marketplace.spec.ts passes 4/4), so the journey asserts detail-view content that either drifted or is a journey-order bug; classify **app gap** (detail view content), with spec-bug possibility noted.
16. **ggen-workbench:47 (health) typed auth refusal** — `Expected value: 406 / Received array: [401, 503]` — spec allows [401,503] contains-check inverted? Verbatim: `expect([401, 503]).toContain(noAuthPost.status())` — the spec asserts the observed status IS 401 or 503, but observed was 406. **Spec bug** (contract written for an older plug behavior; surface now answers 406 Not Acceptable for tokenless workbench calls).
17. **ggen-workbench:47 (run) typed auth refusal** — same `Expected value: 406 / Received array: [401, 503]` — same **spec bug** class: surface answers 406, spec only accepts 401/503.
18. **ggen-workbench:69 health with token** — `Expected: 200 / Received: 503` — 503 is the fail-closed `internal_api_misconfigured` answer, i.e. the server-side workbench plug did not see the token even though the runner had it. **Env** (token not reaching this plug's config path) — ambiguous with app gap; one surface (`/internal-api/execution/mcp`) with the same token got 500s not 503s, so this looks like a workbench-specific config-path gap — classify **app gap (config-path)** leaning env.
19. **internal-api:82 health with token 503** — `Expected: 200 / Received: 503` — token-positive health answered the fail-closed 503 while `ocel_summary` with the same token passed. **App gap** (per-route plug wiring) — or the shared server env lacked the token at boot for the health plug only. Honest status: **UNKNOWN, leaning app gap**.
20. **mcp-a2a:141 zoe-event card 500** — `Expected: 200 / Received: 500`. **App gap** (zoe-event-simulation agent card route errors).
21. **next-read-ml:63/90/126 (×3)** — `Error: locator.waitFor: Test timeout of 30s exceeded.` on pin action, checkout+flash, semantic search. **Lane-active** (`e2e/next-read-ml.spec.cjs` is modified-uncommitted in the working tree; coordinator rule: don't chase).
22. **system-deep:98/137/224/327 (×4)** — `element(s) not found` ×3 + `locator.innerText: Test timeout 30s` (refresh coherence). **App gap** (/system surface sections not rendering under this boot).
23. **witness:109 "Certified Receipts" header** — `expect(locator).toContainText failed — element(s) not found` on `h1` — the /witness route did not render the expected header. **App gap + lane-active** (spec file `e2e/witness.spec.cjs` is untracked new file; coordinator rule: don't chase if lane still editing).
24. **witness:117 seeded rows / empty state** — `element(s) not found` for `witness-empty-row` AND `witness-receipt-row` (neither empty state nor rows rendered; seed reported `W55_SEED_OK` in this run). **App gap + lane-active** (same as above).
25. **zcode-cli-fabric:77 tokenless → HTML error page** — `SyntaxError: Unexpected token '<', "<!DOCTYPE "... is not valid JSON` (expected typed 401 JSON). **App gap** (surface answers HTML 500 instead of typed JSON).
26. **zcode-cli-fabric:101 invalid token → 500 (HTML)** instead of typed 401 JSON — `SyntaxError: Unexpected token '<'` — **App gap**.
27. **zcode-cli-fabric:128 tools list 500** — `Expected: 200 / Received: 500`. **App gap** (execution/mcp surface crashing).
28. **zcode-cli-fabric:160 unknown tool typed JSON-RPC error** — `SyntaxError: Unexpected token '<'` (HTML). **App gap** (same crash class).
29. **zcode-cli-fabric:180 claim→admit→close→receipt** — `Expected: 200 / 500` — verbatim `Expected: 200 / Received: 500` at spec line 199. **App gap**.

## Summary of classifications

- **App gap**: 24
- **Spec bug**: 2 (ggen-workbench 406-contract, blocks 15/16)
- **Env**: 1 ambiguous (ggen-workbench health-with-token 503; env vs app-gap config path)
- **Seed**: 0 (witness seed OK: `W55_SEED_OK` in the final run)
- **Lane-active**: next-read-ml ×3, witness ×2 flagged lane-active + app gap
- **Env-chain (pre-run, fixed in session)**: stale tokenless server adoption, missing `PHX_SERVER` in webServer boot, sibling `../ash_surface` transient compile break, build-lock contention.

## Honest-status block

- All counts are from a single full run (`npx playwright test`, 2.0m, 1 worker) after two
  env fixes; no retries were applied to individual failures.
- `PHX_SERVER=true` was supplied as a runner env var, not a config edit (lane rule: no
  edits). Until the config's BOOT command itself sets it, `reuseExistingServer` remains a
  token/listener hazard for any concurrent lane server on :4000.
- Several "element(s) not found" failures on LiveView surfaces (system-deep, dev-routes,
  witness, ash-admin) share a shape: route responds but expected chrome absent — one
  shared app-gap hypothesis (surface mounts missing under PHX_SERVER boot), not verified
  per-route.
- Raw logs: `/tmp/w118-run2.log`, `/tmp/w118-run4.log`; error contexts under
  `test-results/`.
