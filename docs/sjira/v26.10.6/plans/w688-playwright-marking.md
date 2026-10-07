# W688 Receipt — Playwright e2e for the synthetic-marking surface (W533)

- **Standing: ALIVE** (5/5 passed against a real running server, real HTTP)
- **Subject**: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface
- **New file**: `e2e/a2a-marking.spec.cjs` (wire-level Playwright courts; no UI)
- **Contract source**: `lib/xaas_web/plugs/synthetic_marking_plug.ex`, `lib/xaas_web/endpoint.ex:99` (marking plug mounted before `EuAiActAdmissionPlug`, so refusals are marked), `test/xaas_web/synthetic_marking_test.exs` (plug-level contract re-proved over real HTTP).

## Courts

1. **(a)** POST `/a2a` (JSON-RPC `message/send`) → `x-ai-generated: true` header + top-level `ai_generated: true` body field.
2. **(b1)** W521 Art. 5 admission refusal (params `techniques: ["manipulate_behavior"]` → `REFUSED_EUAIA_*` envelope, HTTP 200, code -32600) is marked (header + field).
3. **(b2)** Token-floor 401 on POST `/a2a` is marked (before_send runs for halted conns).
4. **(c1)** POST `/internal-api/health` without token → 401, no header, no body field.
5. **(c2)** GET `/a2a/v1/.well-known/agent-card.json` → 200, unmarked (marking is POST-keyed).

## Real run tail

Command:

```
PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token PW_PORT=4002 npx playwright test e2e/a2a-marking.spec.cjs --reporter=line
```

Real tail:

```
[1/5] ... (a) POST /a2a response carries x-ai-generated: true + ai_generated field
[2/5] ... (b1) W521 Art. 5 admission refusal envelope is marked
[3/5] ... (b2) token-floor 401 refusal on POST /a2a is established as marked
[4/5] ... (c1) non-AI path (POST under /internal-api) is unmarked
[5/5] ... (c2) GET on /a2a (agent card path) is unmarked — marking is POST-keyed
  5 passed (30.4s)
```

(Actual line-2/3 labels: "(b1) W521 Art. 5 admission refusal envelope is marked" / "(b2) token-floor 401 refusal on POST /a2a is marked".)

## Environment notes

- **Server**: the first playwright boot with `MIX_BUILD_ROOT=_build-laneW688 MIX_ENV=test PW_PORT=4088` timed out its readiness probe (000) — `config/test.exs:73` hardcodes the HTTP port to **4002** in the test env, ignoring `PORT`/`PW_PORT` (runtime.exs PORT only applies in dev). The app did boot; the killed webServer left my orphan beam **PID 56426** listening on 4002 (verified mine: exact BOOT command, cwd /Users/sac/xaas, started 01:29 during my run). I reused it (`reuseExistingServer` via `PW_PORT=4002`) — health probe `GET /internal-api/health` with `Authorization: Bearer dev-e2e-token` → **200** before the green run.
- **Token**: `INTERNAL_API_TOKEN=dev-e2e-token` — the established dev e2e token (w248/w158 receipts), passed through `webServer.env` per `playwright.config.cjs`. No bypass.
- **Fixed during the lane (both test bugs, not product bugs):** (c1) the fail-closed `/internal-api` 401 path returns **406** when the request carries `Accept: application/json` (real server behavior, observed via curl; spec now omits Accept); (c2) I had passed the auth headers object as raw `request.get` options instead of `{headers: ...}`.
- **Left for coordinator (cleanup denied in this session):** orphan beam **PID 56426** (my earlier webServer boot, MIX_ENV=test, port 4002) and `/Users/sac/xaas/_build-laneW688` (~2 GB, cold-dep compile, MIX_ENV=test only). `kill 56426 && rm -rf /Users/sac/xaas/_build-laneW688` — safe: both minted by this lane.
- Product marking code untouched (0 lib/ diff); only the new spec + this receipt.
