# Agent Obliviousness Demonstration — /mcp surface (Stage-3, W407)

- Repo: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `d1db2b03` (read-only lane; no tree changes)
- Server: real Phoenix e2e server (same BOOT path as `e2e/mcp-a2a.spec.cjs` / W310), leased port 4097, `INTERNAL_API_TOKEN=w407-token`, readiness probe `/internal-api/health` = 200.
- Suite gate: `PW_PORT=4097 ... npx playwright test e2e/mcp-a2a.spec.cjs` → **5 passed (22.2s)**.
- Date: 2026-10-06

## Claim under demonstration

An unmodified agent harness calls tools normally while the proxy intercepts
unadmitted calls and returns standard JSON-RPC refusals — the refusal is
wire-indistinguishable from an ordinary MCP error response.

## Leg A — normal call passes (tools/list)

Request:

```bash
curl -s -X POST http://localhost:4097/mcp \
  -H 'Authorization: Bearer w407-token' \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

Response (HTTP 200) — exactly the 3 read-only Library tools:

```json
{"id":1,"jsonrpc":"2.0","result":{"tools":[
  {"name":"active_curations_for_grade", ...},
  {"name":"books_by_grade_band", ...},
  {"name":"list_books", ...}]}}
```

Verified tool names list (parsed): `['active_curations_for_grade', 'books_by_grade_band', 'list_books']`

## Leg B — admitted tool call works (tools/call list_books)

Request:

```bash
curl -s -X POST http://localhost:4097/mcp \
  -H 'Authorization: Bearer w407-token' \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_books","arguments":{}}}'
```

Response (HTTP 200): standard MCP `result.content` with real seeded book rows
(excerpt):

```json
{"id":2,"jsonrpc":"2.0","result":{"content":[{"text":"[{\"id\":\"135c046e-...\",\"title\":\"First Words, First Steps\",...},{\"id\":\"66ecc72d-...\",\"title\":\"Senior Year, Zero Gravity\",...},{\"id\":\"19e95501-...\",\"title\":\"Circuits and Constellations\",..."}]}}
```

## Leg C — unadmitted/refused call (the wire-indistinguishable refusal)

Request (nonexistent / write-shaped tool):

```bash
curl -s -X POST http://localhost:4097/mcp \
  -H 'Authorization: Bearer w407-token' \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"delete_all_books","arguments":{}}}'
```

Response (HTTP 200 envelope, typed JSON-RPC error):

```json
{"error":{"code":-32602,"message":"Tool not found: delete_all_books"},"id":3,"jsonrpc":"2.0"}
```

Supplementary (fail-closed auth): tokenless `tools/list` on the same surface:

```json
{"error":"unauthorized","detail":"missing or invalid Bearer token"}
```
→ HTTP 401, fail-closed per the API-auth floor.

## Verdict

**DEMO-EVIDENCED.** The unmodified harness shape (plain JSON-RPC over HTTP)
exercises Leg A/B without modification; the unadmitted call (Leg C) is
intercepted and answered with a standard JSON-RPC error object
(`-32602 Tool not found`) — same envelope, same content-type, same transport
as the admitted legs. The refusing call is wire-indistinguishable from a
normal MCP error; the agent cannot tell policy refusal from tool absence
from the wire alone.

## Replay

```bash
# boot (mirrors playwright.config.cjs BOOT, leased port):
node ./e2e/global-setup.cjs --catalog
PHX_SERVER=true PORT=4097 INTERNAL_API_TOKEN=w407-token \
  PW_MARKETPLACE_CATALOG=/Users/sac/.cache/tmp/xaas-e2e-marketplace-catalog.json \
  PATH="$HOME/.asdf/shims:$PATH" \
  nohup mix run -e 'Application.put_env(:xaas, :marketplace_catalog_source, System.get_env("PW_MARKETPLACE_CATALOG"))' --no-halt > /tmp/w407-server.log 2>&1 &
# legs: the three curl commands above; teardown: lsof -ti :4097 | xargs kill
```
