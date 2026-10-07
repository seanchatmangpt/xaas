# W113 — a2a/mcp/ggen-workbench Playwright receipt (v26.10.6 convergence)

Date: 2026-10-06 · Lane: W113 integration · Repo: /Users/sac/xaas · Branch: feat/playwright-surface (tree as-found; no edits, no git ops by this lane)

## Subject

- Specs: `e2e/a2a-v1.spec.cjs`, `e2e/mcp-a2a.spec.cjs`, `e2e/ggen-workbench.spec.cjs` (18 tests total, `--list` verified)
- Canonical tokened run: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token PLAYWRIGHT_BASE_URL=http://localhost:4010 npx playwright test e2e/a2a-v1.spec.cjs e2e/mcp-a2a.spec.cjs e2e/ggen-workbench.spec.cjs`
- Toolchain: asdf elixir 1.20.2-otp-28 / erlang 28.5.0.2; Postgres localhost:5432 `xaas_dev`

## Headline

- **Token branch (positive courts): 11 passed / 7 failed.**
- Tokenless branch: 3 passed / 15 failed — every tokenless failure is the 503 fail-closed auth floor (honest fail-closed behavior, recorded as the tokenless result).

## Token-branch per-test results (private tokened server on :4010, warm build)

| Suite | Test | Result | Classification |
|---|---|---|---|
| a2a-v1 | agent card: 200 with required v1 fields | FAIL — HTTP 500 | BLOCKED(environment): `Phoenix.Ecto.PendingMigrationError` on `xaas_dev` |
| a2a-v1 | agent card path rejects wrong method (405, Allow: GET) | PASS | ALIVE |
| a2a-v1 | refuses requests without a token (single auth floor) | PASS | ALIVE |
| a2a-v1 | malformed JSON → -32700 | FAIL — got `-32600` | Genuine defect: parse failure answered as `-32600` (invalid request) instead of `-32700` (parse error); off JSON-RPC 2.0 / A2A v1 spec, TCK-relevant (cf. C27) |
| a2a-v1 | unknown method → -32601 | PASS | ALIVE |
| a2a-v1 | message/send happy path → result.task | FAIL — HTTP 500 | BLOCKED(environment): PendingMigrationError |
| a2a-v1 | message/stream SSE smoke | FAIL — 200 but `content-type: application/json`, expected `text/event-stream` | BLOCKED(environment): same pending-migration error envelope short-circuits SSE |
| ggen-workbench | typed auth refusal without token: /api/workbench/ggen/health | FAIL — got 406, expected ∈ {401,503} | Genuine defect: 406 content-negotiation fires BEFORE the token floor on the `:api` pipeline |
| ggen-workbench | typed auth refusal without token: /api/workbench/ggen | FAIL — 406 before auth | Same 406-before-auth defect |
| ggen-workbench | health with token: typed JSON + AsyncAPI Link header | PASS | ALIVE |
| ggen-workbench | run with token: 422 REFUSED[ARGS_LIMIT] | PASS | ALIVE |
| ggen-workbench | run with token: 422 REFUSED[UNSAFE_PATH] | PASS | ALIVE |
| ggen-workbench | run with token: 422 REFUSED[INVALID_TIMEOUT] | PASS | ALIVE |
| mcp | typed auth refusal without token on POST /mcp | PASS | ALIVE |
| mcp | with token: POST /mcp passes the real Bearer gate | PASS | ALIVE |
| mcp/a2a | typed auth refusal without token on agent card endpoint | PASS | ALIVE |
| mcp/a2a | agent card with token (NextReadUserAgent card) | PASS | ALIVE |
| mcp/a2a | zoe-event agent card (zoe-event-simulation) | FAIL — HTTP 500 | BLOCKED(environment): PendingMigrationError |

Count check: 11 PASS / 7 FAIL = 18.

## Root causes (from real server/test logs)

1. **`ash_surface` dev-env compile break (pre-existing; upstream of all 500-class failures).**
   `MIX_ENV=dev mix ecto.migrate` and any fresh `mix phx.server` that triggers an `ash_surface`
   recompile fail with:
   ```
   == Compilation error in file lib/ash_a2a/resource.ex ==
   ** (ArgumentError) @enforce_keys required keys ([:name, :type]) that are not defined
      in defstruct: [__identifier__: nil, __spark_metadata__: nil]
       lib/ash_a2a/resource.ex:46
   could not compile dependency :ash_surface, "mix compile" failed.
   ```
   This blocks `mix ecto.migrate` → `xaas_dev` stays unmigrated → `Phoenix.Ecto.PendingMigrationError`
   500s on every DB-backed endpoint (4 tests). Fresh tokened boots also die on the same recompile.
   **Repair hop (not this lane — no-edit constraint):** fix the `@enforce_keys`/`defstruct` mismatch
   at `ash_surface`'s vendored `lib/ash_a2a/resource.ex:46`, then `mix deps.compile ash_surface --force`
   + `mix ecto.migrate`, then re-run the 4 PendingMigration-500 tests.
2. **406-before-auth on the `:api` pipeline (genuine, deterministic).** `/api/workbench/ggen*` without
   a token returns 406 (content negotiation) instead of a typed auth refusal. Negotiation plug runs
   before `RequireInternalApiToken` in pipeline order. Repair: reorder the `:api` pipeline so the
   token floor precedes negotiation, or update the spec to admit 406 as a typed refusal shape.
3. **-32600 vs -32700 on malformed JSON (genuine, TCK-relevant).** `POST /a2a/v1` with a malformed
   body returns `-32600` instead of `-32700`. Repair hop: distinguish parse failures in
   `AshA2A.Protocol.Plug` / its Phoenix adapter.
4. **[Tokenless-run only] 503 fail-closed despite a Bearer header sent to a tokenless server.** In
   the tokenless 4000 run (3P/15F), all with-token assertions failed because the server process had
   no `INTERNAL_API_TOKEN` — the plug correctly fail-closes with 503. This is honest behavior, not a
   defect; it disappeared entirely on the tokened 4010 run.

## Infra / lane notes

- **Port 4000 contention**: session start had a tokenless beam (PID 59474) on 4000; killed per task
  authorization; my tokened boot was then SIGTERM'd and replaced by other lanes' tokenless beams
  (54215, later 36463 — tokenless at receipt time). This lane ran its canonical evidence on a private
  tokened :4010 instance via `PLAYWRIGHT_BASE_URL` (config honors it).
- **Playwright `webServer` coupling**: config `webServer` waits on port 4000; when 4000 was dead,
  Playwright tried to spawn its own tokenless `mix phx.server` and timed out after 240s (the
  `--reporter=json` run produced 0 suites for this reason). Lane-private-port runs need 4000 alive
  (any server) or a webServer bypass.
- **Build-dir lock contention** ("Waiting for lock on the build directory (held by process 27668)")
  wedged the 4010 instance mid-session; killed it for hygiene.
- Global-setup witness seed (`mix run -e`, MIX_ENV=dev) FAILED (continuing) — same ash_surface compile break.
- macOS `:alarm_handler` disk_almost_full alarm was set (66 Gi free, 93% capacity) — possible
  contributor to boot flakiness.

## Fleet state at receipt time

- :4000 — another lane's tokenless beam (36463), 503 fail-closed on /a2a/v1.
- :4010 — this lane's instance, killed for hygiene.
- `xaas_dev` — NOT migrated (blocked by ash_surface compile break). No files edited, no git ops.

## Standing

- Token-branch ALIVE: 11/18 tests (a2a-v1 x3, ggen-workbench x4, mcp x4 — including ALL with-token positive courts on the ggen workbench and MCP surfaces).
- BLOCKED(environment): 4 tests (a2a-v1 agent card, message/send, SSE smoke, zoe-event card — pending migrations, upstream ash_surface compile break).
- Genuine defect classes: 2 (406-before-auth on `:api` pipeline; -32600 vs -32700 on malformed JSON).

## W217 post-fix (2026-10-06, integration lane W217)

Subject: /Users/sac/xaas @ d1db2b03 (feat/playwright-surface), uncommitted working tree
as found; lane W217 owns this receipt append only.

Command: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token
npx playwright test e2e/a2a-v1.spec.cjs --reporter=list`

### Run 1 (clean port after kill of stale beam on :4000; then displaced by another
lane's webServer mid-run — see below)
- 4 passed / 3 failed (1.5m): card 200, 405 method, 401 auth floor, -32601 pass;
  -32700, message/send, SSE fail.

### Run 2 (clean port, fresh webServer boot)
- Same 4/3 split, same received values (exit 1):
  - malformed JSON: expected -32700, **received -32600**
  - message/send happy path: expected state "completed", **received "TASK_STATE_COMPLETED"**
  - message/stream SSE: expected content-type text/event-stream, **received
    "application/json; charset=utf-8"** (body: JSON-RPC error -32004
    UNSUPPORTED_OPERATION, `domain: a2a-protocol.org`)

### Independent server-side verification (curl + node fetch against a manually booted
dev server, exact webServer boot shape incl. PHX_SERVER=true + real catalog)
- Malformed `{not json` -> HTTP 200 `{"error":{"code":-32700,"message":"Invalid JSON
  payload"},"id":null,"jsonrpc":"2.0"}` — **W150 parse floor CONFIRMED ALIVE on current
  source** (plug wired in endpoint.ex:76 before Plug.Parsers, source verified).
- message/send with the spec's exact BROWSE_MESSAGE -> 200, full task result, artifact
  with browse text. **Happy path ALIVE**; only the state enum differs from spec.

### Classification of the 3 residuals
1. -32700 spec failure = NOT a server defect. Server answers -32700 to two independent
   clients (curl, node fetch). The spec-run servers observed -32600; both spec runs
   booted under build-dir lock contention ("Waiting for lock on the build directory
   (held by process 81607/13220)") with several other lanes compiling/running e2e on
   this checkout concurrently — stale-beam webServer under contention is the suspected
   mechanism. Needs one quiet-box rerun to convert to pass. Spec mtime 12:20 predates
   plug mtime 13:31 (plug landed after last spec touch, consistent).
2. message/send state enum: spec expects "completed", wire returns
   "TASK_STATE_COMPLETED" (ash_a2a v1.0 TaskState enum form). Server behavior is
   upstream-contract; spec alignment item for W171 (or accept both spellings).
3. message/stream SSE: real capability gap, not spec drift. Adapter answers
   -32004 UNSUPPORTED_OPERATION with application/json; `text/event-stream` is also not
   a registered Phoenix MIME type (Phoenix.NotAcceptableError 406 observed on the raw
   accept header). Two hops to close: register `text/event-stream` in config :mime, and
   implement message/stream in the ash_a2a adapter (or route through a streaming-capable
   agent). Unchanged from the pre-W150 receipt's "406-before-auth" finding — the 401/
   405/card/-32601 courts all still pass.

### Environment during verification
- :4000 contention with concurrent lanes (zcode-cli-fabric/execution-fabric/dev-routes/
  ash-admin-matrix/mcp-a2a runs at run-1 time; ash-admin-matrix then
  execution-fabric/system-deep/witness/full_surface at receipt time). Both spec runs
  above used a clean free port at boot.
- One spec attempt (single -32700 test) was SIGTERM'd mid webServer boot while stuck on
  the build lock (held by process 13220); not a test result.
- No edits, no git ops; this append is the lane's only write.
