# Wave 1 / Agent 01 — Ultracode Domain API Map (XaaS → ZCode)

Scope read: `/Users/sac/xaas/lib/xaas/ultracode/**`, `/Users/sac/xaas/lib/xaas/ultracode.ex`,
`/Users/sac/xaas/test/xaas/ultracode/`, `/Users/sac/xaas/test/xaas_web/execution_fabric_controller_test.exs`,
`/Users/sac/xaas/docs/ultracode/{PROGRESS.md,c4-architecture.md}`, config + router + execution-fabric HTTP surface.
READ-ONLY on /Users/sac/xaas. All line refs below are exact.

**Headline: an external-driver seam ALREADY EXISTS.** `Xaas.Ultracode.Lease` is the provider-pull kernel,
exposed over HTTP as `/internal-api/execution/{hooks,mcp}`, and `mix xaas.gen_zcode_plugin`
(`lib/mix/tasks/xaas.gen_zcode_plugin.ex`) already renders a **ZCode-shaped plugin** (`.mcp.json`,
`hooks.json` with SessionStart/PreToolUse/PostToolUse/Stop, `xaas-worker` agent/skill/command) that
drives Ultracode end-to-end. ZCode does not need to invent a protocol; it needs to run/complete this plugin.

---

## 1. Public actions and state machines

### 1.1 `Xaas.Ultracode.Run` (`lib/xaas/ultracode/run.ex`)

Table `ultracode_runs` (run.ex:40). `state` one_of `[:pending, :running, :completed, :failed, :abandoned]`
(run.ex:186); `standing` one_of `[:unknown, :admitted, :refused, :blocked]` (run.ex:193). `provider`
attribute (run.ex:179-181): `nil` = legacy auto-complete lane; a provider id (`"zcode"`, ...) = provider-pull lane.

Actions (run.ex:97-163):
- `create` — `accept([:goal, :deadline_at, :max_cycles, :epoch_timeout_seconds, :provider])` (run.ex:100-102). Initial state `:pending` (default, run.ex:185).
- `update :start` (run.ex:131-145) — THE admission edge. `accept([])`, required string argument `:exact_subject`; sets `state: :running`, `started_at`, `increment(:cycle)`, and runs `change(Xaas.Ultracode.Changes.CreateFirstEpoch)` which creates `Epoch{cycle: pre-increment cycle, state: :expected}` (changes/create_first_epoch.ex:32-49). Refuses unless `:pending` via `Validations.RunIsPending` (validations/run_is_pending.ex — "run must be :pending to :start").
- `update :advance_cycle` — `increment(:cycle)` (run.ex:104-107).
- `update :mark_expected_epoch` / `:mark_completed_epoch` — timestamp bookkeeping (run.ex:109-115).
- `update :transition_state` — `accept([:state, :standing])`, guarded by `Validations.RunTransitionAllowed` (run.ex:117-122). Explicit edge allow-list (validations/run_transition_allowed.ex): `{:pending, :running}` (test-fixture only), `{:running, :completed}` (production, used by NextEpoch at max_cycles), `{:running, :failed}`, `{:running, :abandoned}`.
- `action :tick, :map` (run.ex:155-162) — generic action, sole body:
  ```elixir
  run(fn _input, _context ->
    case Reactor.run(Xaas.Ultracode.Reactor) do
      {:ok, result} -> {:ok, %{advanced: result}}
      ...
  ```
  No arguments, no per-record binding. Policy: read/tick/advance_cycle/transition_state are `bypass ... authorize_if always()`; everything else `forbid_if always()` (run.ex:63-95).

Run state machine: `:pending --:start--> :running --(NextEpoch at max_cycles)--> :completed`; `:running -> :failed/:abandoned` provisioned, no production caller yet.

### 1.2 `Xaas.Ultracode.Epoch` (`lib/xaas/ultracode/epoch.ex`)

Table `ultracode_epochs` (epoch.ex:29). `state` one_of `[:expected, :running, :completed, :missed, :failed]` (epoch.ex:165). Identity `unique_run_cycle [:run_id, :cycle]` (epoch.ex:230). Lease fields on the row: `lease_token, lease_expires_at, leased_to, worktree, final_head` (epoch.ex:196-214).

Actions (epoch.ex:86-147):
- `create` — `accept([:run_id, :cycle, :exact_subject, :state, :expected_at, :started_at, :worktree])` (epoch.ex:89-91).
- `update :start` — `:expected -> :running` (sets `started_at`), guarded `AtMostOneActiveEpoch` (epoch.ex:93-100).
- `update :complete` — from `:running` only (`EpochTransitionAllowed, from: [:running]`), sets `completed_at` (epoch.ex:102-109).
- `update :mark_missed` — from `[:expected, :running]` (epoch.ex:111-117).
- `update :mark_failed` — from `[:expected, :running]` (epoch.ex:119-125).
- `update :lease` — `accept([:lease_token, :lease_expires_at, :leased_to, :worktree])`, guarded `Validations.LeaseAvailable` (must be `:running`, no live lease) (epoch.ex:131-136). Comment: "callers race-safely bind via Xaas.Ultracode.Lease.claim_next/1's filtered bulk update, not by calling this directly" (epoch.ex:127-130).
- `update :renew_lease` — `accept([:lease_expires_at])` (epoch.ex:138-141).
- `update :record_final_head` — `accept([:final_head])` (epoch.ex:143-146).

Epoch state machine: `:expected --:start--> :running --:complete--> :completed`; `:expected|:running -> :missed` (timeout) or `:failed`; provider lane: `:running` holds until `Lease.close/4`.

### 1.3 `Xaas.Ultracode.Receipt` (`lib/xaas/ultracode/receipt.ex`)

Table `ultracode_receipts` (receipt.ex:26). Only two actions:
- `read :read` — `primary?(true), public?(false)` (receipt.ex:51-54)
- `create :seal` — `accept([:epoch_id, :subject, :outcome, :evidence, :sealed_at])` (receipt.ex:56-59)

Policy: `bypass action(:seal)` only; **no read bypass** — "intentionally unreadable outside the internal kernel path" (receipt.ex:30-48). Attributes: `subject :string` (not null), `outcome` one_of `[:alive, :partial_alive, :blocked, :build_broken, :unsupported, :refused]` (receipt.ex:70-78), `evidence :map` default `%{}`, `sealed_at`. `belongs_to :epoch` non-null (receipt.ex:97-100).

### 1.4 `Xaas.Ultracode.Lease` (`lib/xaas/ultracode/lease.ex`) — the external-driver kernel (plain functions, not Ash actions)

- `claim_next(provider, worker_id \\ nil, opts \\ [])` — `@spec ... :: {:ok, Epoch.t(), String.t(), Run.t()} | {:error, :no_ready_work | term()}` (lease.ex:59-81). Single filtered bulk UPDATE over `state == :running and (is_nil(lease_token) or lease_expires_at < now) and run.provider == ^provider`, oldest first (lease.ex:66-81). Default TTL 30 min (lease.ex:42).
- `renew(lease_token)` — `:ok | {:error, term()}` (lease.ex:127-137).
- `admit_tool(lease_token, tool)` — `{:ok, %{decision: :allow}} | {:error, term()}`; allow-list `~w(Edit Write Read Grep Glob Task TodoWrite WebFetch)`; refuse `~w(Bash git_push publish)` as `{:refused_no_authority, tool}`; unknown → `{:unknown_tool_class, tool}` (lease.ex:44-46, 149-159).
- `record_provider_event(lease_token, event_map)` — telemetry `[:xaas, :ultracode, :provider_event]` (lease.ex:165-180).
- `close(lease_token, final_head, claimed_outcome, evidence \\ %{})` — `{:ok, Epoch.t(), Receipt.t()} | {:error, term()}` (lease.ex:190-213). Head-verified: compares `final_head` against `git -C <epoch.worktree> rev-parse HEAD` (lease.ex:291-298); match → claimed outcome + `"head_verified" => true`; mismatch → `:build_broken`; verifier unavailable → `:partial_alive` (lease.ex:274-287). Then `:record_final_head` → `:complete` → `Receipt :seal`.
- `refuse(lease_token, reason, evidence)` — epoch `:mark_failed`, receipt `outcome: :refused` with `"refusal_reason"` (lease.ex:219-237).

## 2. How the tick DAG is driven

Chain: **Oban cron (`* * * * *`) → `Xaas.Ultracode.Run.Workers.Tick` → `Run.:tick` generic action → `Reactor.run(Xaas.Ultracode.Reactor)` → per active epoch `Reactor.run(Xaas.Ultracode.EpochReactor, %{epoch_id: id})`**.

- AshOban scheduled action, run.ex:44-61: `schedule :tick, "* * * * *"`, `action(:tick)`, `worker_module_name(Xaas.Ultracode.Run.Workers.Tick)`, pinned `queue(:default)` because Oban config only lists `default: 10` (run.ex:50-58).
- Oban supervision: `lib/xaas/application.ex:73-78` — `{Oban, AshOban.config(Application.fetch_env!(:xaas, :ash_domains), Application.fetch_env!(:xaas, Oban))}`. Comment documents the real finding that without `AshOban.config/2` the Cron crontab stays empty and zero jobs ever fire.
- Oban config: `config/config.exs:79-91` — `queues: [default: 10, hold_request_expire_stale_holds: 1, capability_liveness_receipt_check_regressions: 1, webhook_delivery_retry_failed_deliveries: 1]`, `plugins: [{Oban.Plugins.Cron, []}]`, `config :ash_oban, pro?: false` (config.exs:46).
- The trigger id `trig_01X4MaMBcr9DuFhVVZjJuLbQ` appears exactly once in-repo: `docs/ultracode/c4-architecture.md:148` — "The hourly Ultracode routine (`trig_01X4MaMBcr9DuFhVVZjJuLbQ`) is itself an instance of `MigrationInfrastructure`". It is the **Claude cloud routine's** trigger, NOT an AshOban id. Per PROGRESS.md (2026-09-14 entry, "MILESTONE CLOSED"), the in-repo per-minute AshOban tick was proven unattended-alive: `RUN_REACHED_COMPLETED_UNATTENDED` (PROGRESS.md:229-233), standing `ClaudeRoutine → XaaS.Ultracode.Run` = YES (PROGRESS.md:255-267); `PRODUCTION_LIVE = UNKNOWN` (PROGRESS.md:448-449).

`Xaas.Ultracode.Reactor` (reactor.ex:61-105) DAG: `:fetch_active_runs` (reads `state == :running` Runs) → `:advance_missed_epochs` (`MissedEpochs.advance_all/1`, marks stale `:expected/:running` epochs `:missed` + seals `:blocked` receipts, missed_epochs.ex:69-116) → `wait_for` → `:run_active_epochs` (loads `Run.active_epoch`, runs `EpochReactor` per epoch) → `wait_for` → `:advance_next_epochs` (`NextEpoch.advance_all/1`: last epoch `:completed` → create `Epoch{cycle: run.cycle}` + `advance_cycle`, or `transition_state :completed/:admitted` at max_cycles, next_epoch.ex:96-136).

`Xaas.Ultracode.EpochReactor` (epoch_reactor.ex) — inputs `%{epoch_id}`, steps `:observe → :admit → :plan → :construct → :verify → :receipt`, `return(:receipt)` (epoch_reactor.ex:32, 288). Plan branch (epoch_reactor.ex:85-94): `:expected -> :start`; `is_binary(epoch.run.provider) -> :await_provider`; else `:complete`. `:await_provider` is a no-op turn — "the epoch stays `:running` until Lease.close/3 lands verified evidence" (epoch_reactor.ex:113-117). `:construct` has a real `undo/3` (epoch_reactor.ex:129-193). Chicago/Learn are folded into Verify/Receipt (epoch_reactor.ex:8-13); there is no separate CHICAGO or LEARN step despite the c4 doc's 8-step listing (c4-architecture.md:92).

## 3. What an EXTERNAL (ZCode) driver can invoke / observe

### 3.1 Already-built HTTP seam (bearer-gated, fail-closed)

Routes (`lib/xaas_web/router.ex:77-84`): `post("/execution/hooks/:event", ExecutionFabricController, :hook)` and `post("/execution/mcp", ExecutionFabricController, :mcp)` under `/internal-api`, piped through `:require_internal_api_token`. Test proves gate: unset token → 503, wrong bearer → 401 (test/xaas_web/execution_fabric_controller_test.exs:14-16).

MCP JSON-RPC 2.0 tools (`lib/xaas_web/controllers/execution_fabric_controller.ex:28-96`), dispatch :258-319:
- `claim_next` `{provider, provider_worker_id?}` → `{lease_token, lease_expires_at, epoch_id, cycle, exact_subject, goal, worktree}` (controller:258-275); provider defaults `"zcode"` (controller:259).
- `heartbeat` `{lease_token}` → `Lease.renew/1`.
- `admit_tool` `{lease_token, tool}` → allow or typed 403/JSON-RPC isError.
- `record_provider_event` `{lease_token, event: {...}}`.
- `close_candidate` `{lease_token, final_head, outcome, evidence?}` — outcome string, case-insensitive over `~w(alive partial_alive blocked build_broken unsupported refused)`, invalid → `:partial_alive` (controller:98, 360-365).
- `refuse` `{lease_token, reason}` — reason via `String.to_existing_atom` (atom-table DoS guard, controller:367-387).

Hook surface `POST /internal-api/execution/hooks/:event` (controller:104-190): `session_start` (ack + telemetry), `pre_tool_use` (admit court; refusal = HTTP 403 `{decision: "deny", reason}`; hook script must convert transport failure to explicit deny `BRCE_UNAVAILABLE`, controller:13-14), `user_prompt_submit|post_tool_use|post_tool_use_failure` (422 on no lease), `stop` (attempts `Lease.close`; without a closeable lease returns `{status: "not_closeable"}` — "Stop without a closeable lease is observed, not fatal", controller:179-184).

### 3.2 Generated ZCode plugin (the bridge artifact)

`mix xaas.gen_zcode_plugin --endpoint http://localhost:4000 [--token-env XAAS_INTERNAL_TOKEN] [--output generated/xaas-zcode-plugin]` (lib/mix/tasks/xaas.gen_zcode_plugin.ex:34-41) renders `priv/templates/zcode_plugin/` (14 files): `.mcp.json` registering `xaas-execution` MCP server at `<endpoint>/internal-api/execution/mcp` with `Bearer ${TOKEN_ENV}`; `hooks/hooks.json` wiring SessionStart/UserPromptSubmit/PreToolUse/PostToolUse/PostToolUseFailure/Stop to node `.mjs` scripts; `.zcode-plugin/plugin.json` (name `xaas-fabric`); `commands/xaas.md`, `skills/xaas-worker/SKILL.md`, `agents/xaas-worker.md`. Note the hook event names in hooks.json (`PostToolUseFailure`) vs controller (`post_tool_use_failure`) — normalization lives in the .mjs scripts.

### 3.3 What is currently impossible from outside the BEAM

- **Creating/admitting a Run over HTTP**: there is NO public HTTP route for `Run :create`/`:start`. The generic `:tick` and all Run mutations are BEAM-internal (Ash action calls). Only `AshGraphql`/`AshJsonApi`/`AshTypescriptRpc` surfaces (`/internal-api/rpc/run|validate`, router.ex:81-82; domain has `AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain` extensions, ultracode.ex:23-25) could reach them, gated by the internal token, and Receipt read is policy-walled (no read bypass, receipt.ex:30-48) — an external observer CANNOT read Receipts via Ash policies; it must observe them via DB, `/internal-api/ocel_summary` (router.ex:79), or telemetry.
- **`Reactor.run/1` itself**: in-process only; external drivers trigger it indirectly by letting the cron fire or by calling lease tools.
- **Observing `Epoch`/`Run` rows**: reads are policy-open (`bypass action_type(:read)`, run.ex:64-66, epoch.ex:34-36) but only over whatever API surface (GraphQL/JSON:API/rpc) exposes those resources under the token gate; no dedicated Ultracode query endpoint exists.
- **Worker identity/registration**: none exists by design — "No worker registry exists by design: worker identity is free-form and travels with the claim" (controller:110-114).

## 4. ZAI provider adapter / Intelligence Plane stubs

- **No `ZAI` module exists.** `grep -rn "ZAI\b" lib/ config/` → only prose mention `docs/ultracode/c4-architecture.md:55,132,177` ("ZAI is a swappable reasoning provider, not the architecture"; L4 names like `Provider.ZAI` are listed as *future earned* module names, c4-architecture.md:129-134).
- Intelligence Plane (c4 L2) has only its scaffolds: `Xaas.Planning.AdapterRegistry` — `@adapters %{}` "empty on purpose"; `adapter_for/1` hardcoded `{:error, :no_adapter_registered}` (lib/xaas/planning/adapter_registry.ex:26, 44-46); regime router returns UNSUPPORTED end-to-end.
- The **actuation provider lane** IS real and is the de-facto provider adapter: `Run.provider` string attribute (run.ex:179-181) + `Xaas.Ultracode.Lease` + execution-fabric HTTP. `"zcode"` is the default provider name in the controller (controller:117, 259) and in the generated plugin. `Xaas.Marketplace.Provider` (lib/xaas/marketplace/provider.ex) is marketplace-vendor business, unrelated to actuation. `Xaas.Actuation.run/4` (lib/xaas/actuation.ex:11-37) is the separate consequential-action DO kernel (`Xaas.Actuation.Reactor`), not the Ultracode executor path.

## 5. Receipt shape + external reading

Sealed via `Receipt :seal` from 4 call sites: EpochReactor `:receipt` step (epoch_reactor.ex:259-285), EpochReactor `:construct` undo (`:build_broken`, epoch_reactor.ex:155-167), MissedEpochs (`:blocked`, missed_epochs.ex:88-104), Lease.close/refuse. Attributes: `id` (uuid pk), `epoch_id` (non-null FK), `subject`, `outcome` (6-value vocabulary), `evidence` (free map; observed keys: `expected_state`, `observed_state`, `head_verified`, `observed_head`, `verifier_unavailable`, `undo_reason`, `action_taken`, `refusal_reason`, `epoch_timeout_seconds`), `sealed_at`, timestamps. External observation paths: (a) direct Postgres (`ultracode_receipts`) — what the PROGRESS live trial did; (b) `/internal-api/ocel_summary` (router.ex:79) since Ash telemetry is OCEL-emitted (`config :ash, :tracer, [OpentelemetryAsh, Xaas.Telemetry.OcelAshEmitter]`, config.exs:41-43); (c) `:telemetry` events `[:xaas, :ultracode, :provider_event|:provider_session]`. Ash-policy reads are deliberately refused outside the kernel.

## 6. Test-verified calling conventions (real usage)

- In-BEAM: `Run |> Ash.Changeset.for_create(:create, %{goal: "...", max_cycles: 1, provider: "zcode-test"}, authorize?: false) |> Ash.create!()`, then `for_update(:start, %{exact_subject: git_head})`, then repeated `Reactor.run(Xaas.Ultracode.Reactor)` = one tick each (test/xaas/ultracode/run_start_test.exs:44-77). `exact_subject` convention = `git rev-parse HEAD` of the subject repo (run_start_test.exs:28-30).
- Provider loop: `Lease.claim_next("zcode-test", "worker-1")` → `{:ok, epoch, token, run}`; `Lease.close(token, head, :alive, %{})`; `Lease.refuse(token, :reason)` (test/xaas/ultracode/lease_test.exs:51-160). Epoch must be `:running` to be claimable — in tests it is created directly in `:running`; in production the tick's `:construct :start` moves `:expected -> :running` first, and only the NEXT tick hits `:await_provider`.
- HTTP loop fully proven over ConnCase with real worktrees: test/xaas_web/execution_fabric_controller_test.exs:57-107 (run create with `provider:` + epoch `state: :running` fixtures, then claim_next → admit_tool → close_candidate/refuse over the wire).

## 7. Gaps for the ZCode connection (wave-relevant)

1. No HTTP path to create/admit a Run (`:create`/`:start` unreachable from outside the BEAM) — a ZCode-side "new Run" needs either an added internal-API route or an existing generic surface (rpc/GraphQL) wired for it.
2. Receipt reads policy-walled; external observers need DB access or a new read endpoint.
3. `hooks.json.eex` uses `${CLAUDE_PLUGIN_ROOT}` — generated for Claude-Code plugin layout; whether ZCode's plugin loader honors the same env var/shape is a ZCode-repo question.
4. The claim window depends on a tick firing between `:start` and `claim_next` (epoch must reach `:running`); at 1-minute cron cadence a provider can claim within ~1 tick.
5. `admit_tool` refuses `Bash`/`git_push` for lease-held work (lease.ex:46) — a ZCode executor whose loop requires Bash would need the allow-list widened on the XaaS side (ontology fact, not a ZCode workaround).
