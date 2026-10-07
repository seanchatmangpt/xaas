# W173 — Boot-chain validation receipt (v26.10.6 convergence)

- **Lane**: W173 (integration; owns this receipt only — no edits, no git)
- **Subject**: /Users/sac/xaas, branch `feat/playwright-surface` (pre-run tree; no changes made by this lane)
- **Date**: 2026-10-06
- **Gate**: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test e2e/internal-api.spec.cjs e2e/a2a-v1.spec.cjs e2e/witness.spec.cjs`
- **Raw exit tail**: `11 failed / 3 passed (1.9m)`

## Boot health (the thing being validated)

The fixed boot chain itself **worked**:

| Check | Result | Evidence |
|---|---|---|
| Port 4000 cleared | OK | `lsof -ti :4000` empty after kill → `PORT_4000_CLEAR` |
| webServer fresh boot (PHX_SERVER=true + catalog + globalSetup) | OK | Playwright booted `mix phx.server` fresh (1.9m run incl. boot); server answering on :4000 after the run |
| globalSetup catalog | OK — **13 packs** | `$TMPDIR/xaas-e2e-marketplace-catalog.json` written 13:41 by the run, `packs: 13` |
| globalSetup witness seed | ran | globalSetup is never-throw; W55 seed step executed (`MIX_ENV=test mix run e2e/seed-witness.exs`); explicit W55_SEED_OK marker not independently captured |
| Token passthrough | OK | `/internal-api/health` with `dev-e2e-token` reached the controller (returned health JSON, not 401); without token → 401 fail-closed |

## Per-file results (3 passed / 11 failed)

| File | Result |
|---|---|
| e2e/internal-api.spec.cjs | 0/4 — all failures `Expected: 200 / Received: 503` |
| e2e/a2a-v1.spec.cjs | 5 failed, all `Expected: 200 / Received: 503`; 1 passed |
| e2e/witness.spec.cjs | 1 failure incl. "renders the read-only certified receipts table"; rest passed |

**Uniform failure signature across all 11 failures: `Expected: 200 / Received: 503`.** No timeouts, no boot failure, no 401s, no -32700/-32601 semantic mismatches.

## Root cause (pre-existing, environmental — NOT the boot chain)

`/internal-api/health` aggregates a sub-check on `ontop` (`http://ontop:8080`, the docker-compose service hostname per `lib/xaas_web/plugs/ontop_proxy_plug.ex`). In native dev there is no such host: `%Req.TransportError{reason: :nxdomain}`. `lib/xaas_web/controllers/health_controller.ex:76` is fail-closed: `put_status(if all_ok?, do: 200, else: 503)` — so the single nxdomain sub-check degrades the whole health response to 503, and every surface that gates on health 200 fails. All other sub-checks were `ok` (accounts, billing, governance, ledger, marketplace, operations, platform, repo, ultracode_tick).

The a2a v1 surface (which expects 200 on the card) and internal-api tests inherit the same 503. This is an external dependency of the native-dev environment (ontop runs under `docker-compose.ontop.yaml`, not started here), not a regression in the boot chain, the PHX_SERVER seam, W100 plumbing, or token passthrough.

## Lane-active classification

Failures are **NOT** in `e2e/a2a-v1.spec.cjs` logic itself: the failing assertions are plain `expect(status).toBe(200)` against a live 503. No -32700-alignment (W150) edits were implicated — the -32700 test failed with 503 before reaching any JSON-RPC body assertions. Classify all 11 as **environmental (ontop health aggregation), not lane-active**.

## Falsifier for the next rerun

Start ontop (or point `config :xaas, :ontop_base_url` at a reachable stub / mark the sub-check non-fatal in dev) and rerun the same 3-file gate: if the 11 failures drop to 0 with zero code changes, the 503 root-cause is confirmed as purely the ontop sub-check.

## Standing

- Boot chain (PHX_SERVER seam + W100 plumbing + token passthrough): **ALIVE** (observed fresh boot, 13-pack catalog, token reaching controller)
- 3-file e2e gate as a whole: **BLOCKED(ENVIRONMENTAL)** — ontop nxdomain → fail-closed 503 aggregation
