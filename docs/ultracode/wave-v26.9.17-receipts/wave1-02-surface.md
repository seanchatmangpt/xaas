# Wave 1 / Agent 2 — Lawful external surfaces for observing/driving Ultracode (XaaS)

Read-only survey of /Users/sac/xaas @ branch `feat/execution-actuation-fabric` (local checkout; NOT merged to main — `git branch --merged main` lists no ultracode/execution branch). All paths relative to `/Users/sac/xaas/` unless absolute.

Repo context: branch tip `37aaa85` "test(execution-fabric): Chicago qualification of the HTTP surface over real Postgres"; the execution fabric (Lease + HTTP + generated ZCode plugin) landed in `1d0d81a` + `fd829dc` on this branch. Ultracode runtime itself came from `feat/ultracode-runtime` (PR #45, per docs/ultracode/PROGRESS.md:594).

---

## 1. HTTP/JSON/GraphQL APIs exposing Ultracode

### 1a. YES — the Execution Fabric (purpose-built for a ZCode executor)

`lib/xaas_web/router.ex:68-84` — scope `/internal-api`, pipeline `[:api, :require_internal_api_token]`:

- `POST /internal-api/execution/hooks/:event` (router.ex:82) → `XaasWeb.ExecutionFabricController.hook/2`
  - events (`execution_fabric_controller.ex:110-190`): `session_start` (ack, telemetry only), `pre_tool_use` (**admission court**; refusal = HTTP 403 typed reason; transport failure must be converted to deny by the hook client), `user_prompt_submit`/`post_tool_use`/`post_tool_use_failure` (record events, 422 on missing lease), `stop` (attempts head-verified closure; stop-without-closeable-lease returns `not_closeable`, never silently closes).
- `POST /internal-api/execution/mcp` (router.ex:83) → stateless MCP JSON-RPC 2.0 (`execution_fabric_controller.ex:196-256`). Tools (`:28-96`):
  - `claim_next` — claims oldest lease-free `:running` Epoch of a provider-pull Run; returns lease_token, epoch_id, cycle, exact_subject, goal, worktree. Provider defaults to `"zcode"` (`:259`).
  - `heartbeat` (renew lease TTL, default 30 min, `lib/xaas/ultracode/lease.ex:42`), `admit_tool`, `record_provider_event`, `close_candidate` (requires final_head; outcome vocabulary `alive|partial_alive|blocked|build_broken|unsupported|refused`, `:98`), `refuse`.

**Auth**: `Authorization: Bearer <INTERNAL_API_TOKEN env value>`; constant-time compare; env unset ⇒ 503 fail-closed (`lib/xaas_web/plugs/require_internal_api_token.ex:20-44`). fly.toml comments name INTERNAL_API_TOKEN among required production runtime secrets (`fly.toml:9-11`).

**Backend seam**: `Xaas.Ultracode.Lease` (`lib/xaas/ultracode/lease.ex`) — lease lives on `Xaas.Ultracode.Epoch` fields (`lease_token/lease_expires_at/leased_to/worktree/final_head`, `epoch.ex:196-214`); claim is a race-safe filtered bulk UPDATE (`lease.ex:83-122`); `admit_tool` allows only construction tools `Edit Write Read Grep Glob Task TodoWrite WebFetch`, refuses consequence tools `Bash git_push publish` and ALL unknown classes (`lease.ex:44-47,151-159`); closure is head-verified via `git -C <worktree> rev-parse HEAD`, mismatch ⇒ `build_broken`, verifier unavailable ⇒ `partial_alive` (`lease.ex:274-298`).

**Generated ZCode plugin already exists** (`lib/mix/tasks/xaas.gen_zcode_plugin.ex`, templates at `priv/templates/zcode_plugin/`, rendered artifact at `generated/xaas-zcode-plugin/`): `.mcp.json` registers MCP server `xaas-execution` at `http://localhost:4000/internal-api/execution/mcp` with `Bearer ${ZCODE_XAAS_TOKEN}`; `hooks/` (session_start, pre_tool_use, post_tool_use, post_tool_failure, user_prompt_submit, stop, xaas_common, xaas-lease .mjs); `commands/xaas.md`; `skills/xaas-worker/`; `agents/xaas-worker.md`.

### 1b. NO — Ultracode is absent from every other API surface (load-bearing)

- `/api` AshJsonApi (`lib/xaas_web/api_router.ex:11-21`): domains = Accounts, Billing, Governance, Ledger, Marketplace, Operations, Platform. **No Xaas.Ultracode** — despite `Xaas.Ultracode` declaring `AshJsonApi.Domain` (`lib/xaas/ultracode.ex:25`), it is not mounted.
- `/internal-api` catch-all AshJsonApi (`lib/xaas_web/internal_api_router.ex:10-13`): Xaas.Operations only. Named routes before it (`router.ex:68-84`): capability_liveness_regressions, ocel_summary, prometheus/query, health, rpc/run, rpc/validate, execution hooks/mcp.
- AshTypescript RPC `/internal-api/rpc/run|validate` (`router.ex:75-76`, `ash_typescript_rpc_controller.ex:12-20`): domain must extend `AshTypescript.Rpc` — only Xaas.Operations/Billing/Accounts do (`lib/xaas/operations.ex:8`, `billing.ex:4`, `accounts.ex:4`). `ultracode.ex:25` does not. **Ultracode unreachable via RPC.**
- GraphQL: `lib/xaas/graphql_schema.ex:4-6` — domains = Operations, Library only, and no Absinthe plug is mounted anywhere in router.ex/endpoint.ex. Dead surface.
- `/mcp` (`router.ex:125-134`): AshAi MCP, read-only Library tools. `/a2a` (`router.ex:145-152`): Next Read persona. `/webhooks/stripe` (`router.ex:53-57`). None touch Ultracode.
- Dev-only (`config :xaas, dev_routes`, `router.ex:208-235`): `/dev/dashboard` (LiveDashboard), `/dev/dashboards/autofde-lab`, `/admin` (AshAdmin — Ultracode IS shown: `ultracode.ex:27-29`), dev MCP `/ash_ai/mcp` (`endpoint.ex:40-45`). Dev convenience only, no token gate (browser session).
- Sockets: only `/live` LiveView socket (`endpoint.ex:24`); no channels, no Ultracode PubSub surface beyond the generic `Xaas.PubSub`.

### 1c. Gap (load-bearing)

**No HTTP surface creates or starts a Run.** `Run.:create` / `Run.:start` (run.ex:100-145) are reachable only via direct Ash invocation (IEx/`mix run`/AshAdmin-dev/direct DB+court bypass). The Execution Fabric only *leases and closes* existing provider-pull Epochs; it cannot bootstrap a Run. An external ZCode process can be the **executor** over HTTP; a **driver** (Run creation) has no HTTP path today.

## 2. How Ultracode ticks in production

- AshOban scheduled action: `* * * * *` → `:tick` generic action, queue pinned `:default` (`run.ex:44-61`) → `Reactor.run(Xaas.Ultracode.Reactor)` (`run.ex:155-162`) → 4-step tick DAG (fetch runs / advance missed / run EpochReactor per active epoch / advance next epochs, `lib/xaas/ultracode/reactor.ex:61-105`); per-epoch 6-step DAG observe→admit→plan→construct→verify→receipt (`epoch_reactor.ex`). Provider-pull branch: `run.provider` set ⇒ plan = `:await_provider`, no auto-complete, epoch completes only via `Lease.close/3` (`epoch_reactor.ex:82-95,113-117`).
- Oban is supervised with AshOban-derived crontab: `{Oban, AshOban.config(ash_domains, Oban config)}` (`lib/xaas/application.ex:73-77`); `Xaas.Ultracode` is in `:ash_domains` (`config/config.exs:13-26`); Oban config `config.exs:73-83` (queues default:10 + 3 convention queues; `plugins: [{Oban.Plugins.Cron, []}]`); `ash_oban, pro?: false` (`config.exs:46`); test env `testing: :manual` (`config/test.exs:91`).
- **Unattended ticking: verified in dev, NOT verified in production.** `docs/ultracode/PROGRESS.md:228-233` — `RUN_REACHED_COMPLETED_UNATTENDED` (Oban cron fired Tick 4x, run completed with zero external driver); reproduced independently (`:300-314`). Explicitly `PRODUCTION_LIVE = UNKNOWN` — `MIX_ENV=prod` compile is broken repo-wide (ex4pm task needs igniter, scoped out of prod, `PROGRESS.md:437-449`). Deployment target exists (Fly: `fly.toml` `internal_port=4000`, `min_machines_running=1`, `PHX_SERVER=true`) but whether this branch is deployed there is unobserved.

## 3. Local dev shape

- `mix phx.server` / `MIX_ENV=dev mix run --no-halt` (the mode used for the live falsifier). HTTP binds `127.0.0.1:4000` (`config/dev.exs:13,64`; PORT env). Test env port 4002 (`test.exs:53`). Prod binds all interfaces, PORT default 4000 (`runtime.exs:93-104`).
- DB: Postgres, host `localhost` port `5432` (env `DEV_DB_HOSTNAME`/`DEV_DB_PORT`), database `xaas_dev`, two repos (LegacyRepo + Xaas.Repo) sharing it (`dev.exs:23-52`). compose.yaml ships `pgvector/pgvector:pg15` (`compose.yaml:10`), publishes `${POSTGRES_PORT:-5432}`, its `POSTGRES_DB` is `kanban_dev` (book default; actual dev URL comes from `secrets/.databaseurl` via compose secret, `compose.yaml:57,164`). Test DB `xaas_test[+partition]` (`test.exs:21,30`). Prod: single `DATABASE_URL` shared by both repos (`runtime.exs:36-69`).
- Stack: web 4000, grafana 3000, prometheus 9090, loki/promtail/alloy (`compose.yaml`); k8s manifests in `k8s/`; AWS swarm terraform in `environments/`.

## 4. Candidate external surfaces — capability matrix

| Surface | Can do | Cannot | Prereqs |
|---|---|---|---|
| `POST /internal-api/execution/mcp` (MCP JSON-RPC) | claim_next / heartbeat / admit_tool / record_provider_event / close_candidate / refuse — full worker lifecycle over `Run/Epoch/Receipt` | create/start a Run; read arbitrary resources; use Bash/push-class tools (refused); bypass head verification | network to :4000; server `INTERNAL_API_TOKEN` set; client token; a provider-pull Run (`Run.provider="zcode"`) with `:running` Epoch |
| `POST /internal-api/execution/hooks/:event` | hook-driven integration (session_start, pre_tool_use admission, observations, stop) | same as above; hooks are advisory except pre_tool_use (deny) and stop (close attempt) | same |
| `GET /internal-api/health`, `/ocel_summary`, `/capability_liveness_regressions`, `/prometheus/query` (token-gated) | observe app/receipt health, OCEL summaries, bounded Prometheus queries | see Ultracode Run/Epoch rows (not exposed) | token |
| Direct DB read (Postgres :5432, `xaas_dev`) | read `ultracode_runs`/`ultracode_epochs`/`ultracode_receipts` + `oban_jobs` — perfect observability, e.g. detect claim/lease-expiry | lawful mutation (Ash validations/policies, Oban ownership; hand-writing rows bypasses receipt sealing) | DEV_DB_* env or secrets/.databaseurl; DB reachable |
| `mix run -e` / release `bin/xaas rpc|remote` | everything: `Xaas.Ultracode.Run` create/`start`, `Reactor.run/1`, `Lease.*` | — (this is how Run bootstrap must happen today) | shell on host, compiled app, env (DEV_DB_*, token); heavyweight; carries full actuation authority — should stay operator-gated |
| Logs/telemetry | `[:xaas, :ultracode, :provider_session|:provider_event]` telemetry (`execution_fabric_controller.ex:114`, `lease.ex:169`); OCEL v2 ndjson (`priv/ocel/`, per mix.exs:80-82); PromEx/Grafana/Prometheus (3000/9090) | drive anything | file/metrics access |
| `/internal-api/sparql` (Ontop proxy, `router.ex:173-177`) | SPARQL over whatever R2RML maps | unverified whether ultracode tables are mapped | token + Ontop running |
| Dev-only (dev_routes) | AshAdmin `/admin` can view/act on Ultracode domain; LiveDashboard | not a production surface | dev server, browser |

## 5. Recommended surface for an external ZCode process

**Primary: the Execution Fabric MCP endpoint (`/internal-api/execution/mcp`) behind `RequireInternalApiToken`** — it is the purpose-built, receipt-bearing lease protocol; a rendered ZCode plugin already targets it (`generated/xaas-zcode-plugin/.mcp.json`), the transport is stateless (no SSE/session), refusals are typed (JSON-RPC `isError` with typed reason), closure is head-verified server-side, and the client-side token var is `ZCODE_XAAS_TOKEN`. Use the hooks surface for pre-tool-use admission if ZCode hook integration is desired (defense-in-depth, transport failure must deny). Use direct DB reads as the observation channel (Run/Epoch/Receipt/oban_jobs) rather than inventing read APIs.

**Tradeoffs / gaps to plan around:**
1. No HTTP Run bootstrap — an operator/oracle step (mix run/IEx, or a future internal-api route) must create+start a provider-pull Run before `claim_next` returns work. Wave should name this as the driver-side gap.
2. Standing is branch-local: fabric code lives on `feat/execution-actuation-fabric` (unmerged); live unattended ticking proven only on a dev node; `PRODUCTION_LIVE = UNKNOWN`.
3. Consequence tools (Bash, git push) are refused by the admission court by design — ZCode worker runs under a construction-only fence; `admit_tool` on unknown classes denies (fail-closed).
4. Lease TTL 30 min — long ZCode tasks must heartbeat.
5. `INTERNAL_API_TOKEN` is read via `System.get_env` at request time (no release config) — must be set in the serving environment or everything 503s (fail-closed).
