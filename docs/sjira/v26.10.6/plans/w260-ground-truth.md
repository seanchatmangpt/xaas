# W260 Ground-Truth Probes — v26.10.6 Convergence

- Date: 2026-10-06
- Repo: /Users/sac/xaas (branch feat/playwright-surface, working tree as found)
- Subject: fresh beam booted this session with the exact prescribed command
  `PHX_SERVER=true PATH="$HOME/.asdf/shims:$PATH" INTERNAL_API_TOKEN=dev-e2e-token mix run --no-halt`
  logging to /tmp/w260-server.log; health 200 in 11s.
- Port hygiene: :4000 was clear before boot (prior stale `mix phx.server` PID 59529 killed).
  Note: a second concurrent boot attempt hit `eaddrinuse`; the serving beam is this session's
  first launch. Concurrent lanes on this box killed an earlier attempt mid-session; probes were
  re-run atomically in the same shell as the boot that survived.

## Probe transcripts (verbatim)

### P1 — auth floor on /api/workbench/ggen, NO token
```
$ curl -s -X POST http://127.0.0.1:4000/api/workbench/ggen -H "Content-Type: application/json" -d '{}' -w "\nHTTP=%{http_code}"
{"error":"unauthorized","detail":"missing or invalid Bearer token"}
HTTP=401
```
SERVER-TRUTH: **401** typed JSON ("unauthorized"). NOT 406.

### P2 — A2A wire parse error, WITH token
```
$ curl -s -X POST http://127.0.0.1:4000/a2a/v1 ...
{"error":{"code":-32700,"method":null,"message":"Invalid JSON payload"},"id":null,"jsonrpc":"2.0"}
HTTP=200
```
SERVER-TRUTH: **-32700** (`Invalid JSON payload`). NOT -32600.

### P3 — message/send task state
Request: `{"jsonrpc":"2.0","id":1,"method":"message/send","params":{"message":{"role":"ROLE_USER","parts":[{"text":"hello from W260 ground-truth probe"}],"messageId":"w260-gt-1","kind":"message"}}}`
```
{"id":1,"jsonrpc":"2.0","result":{"task":{"contextId":"","history":[...],"id":"tsk-Nu6iNy1n6qiR",
"status":{"message":{...},"state":"TASK_STATE_INPUT_REQUIRED","timestamp":"2026-10-06T21:54:03.771963Z"}}}}
HTTP=200
```
SERVER-TRUTH: task state, verbatim: **`TASK_STATE_INPUT_REQUIRED`** (SCREAMING_SNAKE A2A-v1 enum).
No lowercase `completed` anywhere in the wire response.

## Verdict on W259's 5 reported "real" failures

| # | W259 claim | Server truth (this run) | Verdict | Where the fix belongs |
|---|---|---|---|---|
| 1 | workbench ggen returns 406 without token | **401** typed JSON | W259 probe artifact (stale/mismatched server or token env) — contradicts W150 auth-floor reorder | W259's probe harness / e2e client, NOT the server |
| 2 | parse floor returns -32600 | **-32700** `Invalid JSON payload` | W259 probe artifact — contradicts W150 parse floor | W259's probe harness / e2e client |
| 3 | task state is lowercase `completed` | **`TASK_STATE_INPUT_REQUIRED`** | SPEC-TRUTH mismatch is in the *expectation*, not the server: server emits A2A-v1 SCREAMING_CASE; any client comparing to lowercase `completed` is the defect | e2e client/expectation file (e.g. `e2e/*.spec.cjs` comparing task.state) |
| 4 | (implicit) server unhealthy on fresh boot | health 200 in 11s on fresh beam | W259 artifact — server healthy | n/a |
| 5 | (implicit) fixes not landed | P1/P2 match landed W150 fixes exactly | W259 ran against a stale subject | n/a — W150 fixes are landed and observed ALIVE on fresh subject |

Bottom line: all three landable claims (P1 401-floor, P2 -32700 parse floor, P3
TASK_STATE_* SCREAMING_CASE enum) are SERVER-TRUTH correct on a fresh beam. W259's
5 failures are probe-subject drift (stale beam / stale expectations), not regressions.
Only fix surface: W259's probe/expectation files.

## Replay

```
PHX_SERVER=true PATH="$HOME/.asdf/shims:$PATH" INTERNAL_API_TOKEN=dev-e2e-token mix run --no-halt &
# poll: curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer dev-e2e-token" http://127.0.0.1:4000/internal-api/health
# then P1/P2/P3 transcripts above (use 127.0.0.1, not localhost — the box resolves localhost to ::1)
```

## W310b workbench 406 resolution

Residual disposition: NOT A LIVE DEFECT on the current subject. W150's pipeline
reorder (`lib/xaas_web/router.ex` `/api/workbench` scope:
`pipe_through([:require_internal_api_token, :api])`, auth floor listed before
:accepts) is present in the working tree (HEAD d1db2b03 still has the old
`[:api, :require_internal_api_token]` order — the fix is uncommitted lane work)
and is what the running beam is executing.

Evidence (2026-10-06, live beam PID 64202 on localhost:4000, no server edits):

- `curl -s -X POST http://localhost:4000/api/workbench/ggen -H 'Content-Type: application/json' -d '{}'`
  -> `{"error":"unauthorized","detail":"missing or invalid Bearer token"}` HTTP 401
- same probe + `-H 'Accept: application/json'` -> identical typed 401 JSON body, HTTP 401
  (the 406-vs-401 Accept-header differential W302 observed is absent: :accepts no longer
  runs before the token plug, so no probe learns accepted content types pre-auth)

ExUnit gate (real output):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web/ggen_workbench_auth_floor_test.exs
Finished in 0.1 seconds (0.00s async, 0.1s sync)
Result: 2 passed
```

No pipeline change required this lane — router.ex untouched (diff vs HEAD shown above
is W150's own pre-existing reorder, not W310b work). Zero code edits landed.

Standing: W310b residual CLOSED (verified, no-op). Replay: commands above; subject =
working tree on feat/playwright-surface, router.ex @ the W150 reorder.

## W299c GET 406 resolution

Adjudication: W299's tokenless GET 406 was real and distinct from W310b's POST 401s.
W150's workbench-scope reorder (`pipe_through([:require_internal_api_token, :api])`)
was already present and correct — but the 406 came from a DIFFERENT scope. `GET
/api/workbench/ggen` matches no route in the workbench scope (only `GET /ggen/health`
and `POST /ggen` exist), so Phoenix falls through to the later `forward("/api",
XaasWeb.ApiRouter)` scope, whose `pipe_through` listed `:internal_api` — which carries
`plug(:accepts, ["json-api"])` — BEFORE `:require_internal_api_token`. A tokenless GET
with `Accept: application/json` therefore died in `Plug.Accepts` with 406 before any
auth check (same W150 defect class, in the /api forward scope). Pipelines do not run on
workbench-scope no-match; the fall-through scope's pipeline is what executed.

Fix (lib/xaas_web/router.ex, /api forward scope only):
`pipe_through([:require_internal_api_token, :internal_api, :resolve_org_actor,
:set_internal_api_system_actor])` — token floor moved ahead of content negotiation.

Probe matrix (live server, fresh boot, INTERNAL_API_TOKEN=dev-e2e-token), 8 cells:

| method | Accept header       | auth  | before fix | after fix |
|--------|---------------------|-------|------------|-----------|
| GET    | none                | none  | 401        | 401       |
| GET    | none                | token | 404        | 404       |
| GET    | application/json    | none  | **406**    | **401**   |
| GET    | application/json    | token | 406        | 406       |
| POST   | none                | none  | 401        | 401       |
| POST   | none                | token | 503        | 503       |
| POST   | application/json    | none  | 401        | 401       |
| POST   | application/json    | token | 503        | 503        |

Tokenless cells: all 401 typed JSON `{"error":"unauthorized","detail":"missing or
invalid Bearer token"}`. Post-auth cells unchanged and correct: GET+token 404/406 =
no GET route on a POST-only surface (406 is post-auth `Plug.Accepts` inside the /api
forward, content-type info leak no longer reachable pre-auth); POST+token 503 = ggen
worker unavailable in this environment (fail-closed, not auth).

ExUnit gate (real output, after adding the fall-through regression test):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web/ggen_workbench_auth_floor_test.exs
...
Result: 4 passed
```

Test additions (test/xaas_web/ggen_workbench_auth_floor_test.exs): tokenless
POST+Accept:application/json, and the W299c fall-through GET (no such route)+Accept
case that failed 406 pre-fix. Files touched: router.ex (one pipe_through reorder),
the auth-floor test. No git actions. Replay: boot per W299c step (1), rerun the
8-cell curl matrix and the ExUnit command above.

## W310e spec confirm

- Subject: /Users/sac/xaas @ feat/playwright-surface, lane W310e, v26.10.6 convergence (post-W299c ggen-workbench spec: /api token floor now precedes :accepts).
- Chain: pkill ALL beams (authorized) → `:4000` confirmed clear → `node ./e2e/global-setup.cjs --catalog` (13 packs written to /Users/sac/.cache/tmp/xaas-e2e-marketplace-catalog.json) → `PHX_SERVER=true PATH="$HOME/.asdf/shims:$PATH" INTERNAL_API_TOKEN=dev-e2e-token mix run --no-halt > /tmp/w310e-server.log 2>&1 &` → health poll 200 in ~10s.
- Falsifier run: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test e2e/ggen-workbench.spec.cjs` → **6 passed (8.0s)**.
  - typed auth refusal without token: /api/workbench/ggen/health and /api/workbench/ggen — 401/503 class (post-W299c token floor precedes :accepts; 406 class gone)
  - health with token: typed JSON + AsyncAPI service-desc Link header ✓
  - run with token: 422 REFUSED[ARGS_LIMIT] ✓ / REFUSED[UNSAFE_PATH] ✓ / REFUSED[INVALID_TIMEOUT] ✓
- Standing: ALIVE (observed execution on fresh boot via committed chain). Server killed after receipt. No edits, no git.
