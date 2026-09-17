# wave1-08 — Concurrency/Ops Fit: XaaS Ultracode epochs → ZCode executor waves

Scope: read-only survey of `/Users/sac/dev/zcode-cli` (executor knobs) and `/Users/sac/xaas` (epoch cadence, worktree discipline), plus the RUNBOOK mapping CONSTRUCT waves onto ZCode subagent waves. Capacity law (≤16 heavyweight flash in flight, top-up-only saturation, [1302] retry, 20-min reap) treated as binding input from operator AGENTS.md (ticket flash-capacity-ladder-001, measured 2026-09-16).

---

## 1. ZCode-side knobs (what a caller controls)

**Model tier selection** — two-tier `model.main` / `model.lite`; `lite` is what subagent work uses:
- `docs/CONFIGURATION.md:212-214` — "`main` is the normal conversation model. `lite` is used for lightweight and subagent work."
- `docs/CONFIGURATION.md:305-307` — "Setting both `model.main` and `model.lite` … makes the custom provider the default for normal, lightweight and subagent work."
- Tier is chosen per model ID, e.g. `zai/glm-5.3-flash` vs `zai/glm-5-turbo` (`docs/CONFIGURATION.md:247-292` example). A dispatcher picks heavyweight vs trivial capacity by pointing `model.lite` at the flash tier.

**Headless dispatch (how XaaS would invoke one agent):**
- `zcode --prompt "..."` — `docs/CONFIGURATION.md:5,313`; `docs/DEVELOPMENT.md:92,110`.
- Other invocable surfaces: `--target`, `app-server`, `agent-server` (`docs/DEVELOPMENT.md:124`); resume via `--resume`/`--continue` (`src/launcher.ts:181`).
- Process spawn mechanics for an embedding caller: `src/app-server-client.ts:121` (`spawn(transport.command, transport.args)`), with a force-kill timer at `src/app-server-client.ts:129,150` — the CLI-side hook for killing a wedged agent.

**Retry (in-process, model-call level):**
- `src/launcher.ts:42` — `const defaultModelRetryMaxRetries = "5"`; `src/launcher.ts:72-73` — env override `ZCODE_MODEL_RETRY_MAX_RETRIES`.
- `docs/CONFIGURATION.md:341-345` — "default retry budget of five retries"; example `ZCODE_MODEL_RETRY_MAX_RETRIES=3 zcode`.
- Retryable: timeouts, dropped streams, rate limits, server/network errors. Non-retryable: auth and invalid-request (`docs/CONFIGURATION.md:357-358`). Rate-limit retryability is exactly the [1302] absorption path.

**Per-call timeout (stream idle):**
- `docs/CONFIGURATION.md:351-356` — `modelStream.idleTimeoutMs`, default `60000` (60 s). Legacy configs may carry `600000`; never overwritten automatically.

**Subagent backgrounding:**
- `docs/CONFIGURATION.md:327-336` — `subagents.autoBackgroundMs` (default `1000`): Agent calls longer than the threshold detach to `/tasks`; `run_in_background: true` detaches immediately.

**What does NOT exist:** no caller-facing global max-agent / max-concurrency knob anywhere in `src/` (grep for `maxConcurrent|concurrency|max.*agent` in `src/` returns nothing relevant). Concurrency ceilings are NOT enforced inside the CLI — the fleet-level ≤16 ceiling must be enforced by the dispatcher (XaaS CONSTRUCT coordinator), which matches the capacity law living in operator law, not in the tool.

---

## 2. XaaS-side cadence (Ultracode Oban/AshOban schedule)

**Tick interval: every minute, real cron:**
- `lib/xaas/ultracode/run.ex:45-46` — `schedule :tick, "* * * * *" do action(:tick)` (AshOban `scheduled_actions`).
- `lib/xaas/ultracode/run.ex:58` — `queue(:default)` explicitly pinned (AshOban's default queue name `run_tick` is not a runnable queue in this repo — enqueue-only otherwise).

**Job concurrency (Oban):**
- `config/config.exs:73-83` — `config :xaas, Oban, queues: [default: 10, ...]` with `plugins: [{Oban.Plugins.Cron, []}]`. So the tick queue runs **10 concurrent Oban jobs max**, cron-driven every minute.
- Wiring is real: `lib/xaas/application.ex:73-76` — `{Oban, AshOban.config([...], Application.fetch_env!(:xaas, Oban))}` (ULTRACODE-50 fix; previously zero `oban_jobs` rows ever appeared).

**Per-tick DAG (`lib/xaas/ultracode/reactor.ex`):**
- `:fetch_active_runs` (:61) → `:advance_missed_epochs` (:69, `wait_for` ordered) → `:run_active_epochs` (:77) → `:advance_next_epochs` (:98, `wait_for`).
- `reactor.ex:77-95` — `run_active_epochs` runs `Reactor.run(Xaas.Ultracode.EpochReactor, ...)` per active epoch via **serial `Enum.map`** — one epoch's full cycle per run per tick, epochs never executed in parallel inside a tick.
- `reactor.ex:44-49` — an epoch completing on THIS tick makes its successor eligible only on the NEXT tick ("one real Oban cron firing later") — evidentiary boundary; ⇒ one CONSTRUCT wave per run per minute, hard ceiling.

**EpochReactor steps (`lib/xaas/ultracode/epoch_reactor.ex`):** `:observe` :36, `:admit` :57, `:plan` :82, `:construct` :108, `:verify` :202, `:receipt` :255. Chicago folded into Verify, Learn into Receipt (moduledoc :6-8).

**Construction lease (the concurrency token):**
- `lib/xaas/ultracode/lease.ex:42` — `@default_lease_ttl_minutes 30`; lease lives on the Epoch row: `lease_token / lease_expires_at / leased_to / worktree / final_head` (lease.ex:12-13).
- `lease.ex:70` — stale-lease reclaim filter `is_nil(lease_token) or lease_expires_at < ^now`; loser of a race sees a typed refusal (:22). Only one provider wins an epoch's construction.
- Today CONSTRUCT is mostly `:await_provider` (`epoch_reactor.ex:110-116`): the lease clock is the external provider's (ZCode executor) to spend. **This is the exact seam the wave plugs into.**

**Hourly-routine provenance:** `docs/ultracode/c4-architecture.md:148` — `trig_01X4MaMBcr9DuFhVVZjJuLbQ` is the legacy hourly routine; the AshOban minute-tick is its self-deleting replacement (drive toward `ClaudeRoutine → XaaS.Ultracode.Run`).

---

## 3. Worktree discipline (how xaas fans out today)

- **Wave worktrees:** `.claude/worktrees/wf_<wave-uuid>-<agent-N>` (top-level listing only): `wf_f48be0b4-c6f-2/-4/-8/-9/-11/-13/-34/-35/-38/-42`, `wf_f6a788f1-b0f-1..4`. Naming = wave id + per-agent index; ~10-14 agents per observed wave — consistent with the ≤16 ceiling.
- **Branches inside worktrees** (`git worktree list`): `codex/<feature>-impl`, `review-<topic>`, `feat/<purpose>` — purpose-named, per-agent; several **detached HEAD** worktrees = dead/abandoned agents, i.e. reaping (20-min silence rule) is empirically necessary, not decorative.
- **Fanout dir:** `~/xaas/fanout/r80, r84` contain pack material (`ggen.toml, ontology.ttl, templates`) — fanout of ontology projections, not code worktrees. Pack authorship stays on 法面; agent waves work 産面 in worktrees.
- **Merge gates (git log --merges):** PR merges (`Merge pull request #46/#45 from .../feat/ultracode-runtime`) plus a local **gated merge-branch pattern**: `Merge branch 'pr40-merge'`, `Merge branch 'eds-merge'` — merge candidate into a local integration branch, gate it, then land on main. Non-FF, auditable, one landing at a time.
- **Branch base discipline:** repo HEAD sits on `feat/execution-actuation-fabric`, not `main` — never assume default branch (記 law, confirmed in practice).

**Pattern ZCode executor waves must mirror:** `wf_<epoch-or-wave-id>-<agent-N>` worktree dirs; purpose branches per agent; agents never push; one gated `--no-ff` integration merge per cycle; successor epoch waits for the next tick.

---

## 4. RUNBOOK — CONSTRUCT waves → ZCode subagent waves

**Trigger.** Each Oban minute-tick (`run.ex:46`) runs at most one CONSTRUCT wave per active Run (`reactor.ex:77-95` serial). One wave = one Epoch's construction lease (`lease.ex`), handed to the ZCode dispatcher at the `:await_provider` seam (`epoch_reactor.ex:110`).

**Dispatch.** Per agent: fresh worktree `.claude/worktrees/wf_<epoch-id>-<N>`, purpose branch, one `zcode --prompt "<ticket-path> + worktree"` process (`docs/DEVELOPMENT.md:92`), or `agent-server`/app-server transport (`src/app-server-client.ts:121`) when receipts stream back programmatically. Model tier per capacity class: `model.lite` = flash/heavyweight tier; trivial batch tasks may exceed 16 only if separately measured (20/50/100 clean) — never mixed into a heavyweight wave's count.

**In-flight ceiling.** Heavyweight flash ≤16 concurrently, fleet-wide, enforced by the dispatcher (no CLI knob exists — see §1). Saturation by top-up only: start ≤6, add +1 per drain signal, never bulk-burst. 17-25 = caution band (rider-setpoint territory only).

**[1302] retry policy.**
- In-process: `ZCODE_MODEL_RETRY_MAX_RETRIES` (default 5, `src/launcher.ts:42`) absorbs transient stream/rate-limit errors (`docs/CONFIGURATION.md:357-358`) — leave at default for agent processes.
- Cross-process: an isolated `[1302]` death is absorbed by transparent re-dispatch (same ticket, same worktree, fresh process, counts as top-up). Stream idle death: `modelStream.idleTimeoutMs` fires first (60 s, `docs/CONFIGURATION.md:353`); force-kill fallback `app-server-client.ts:150`.
- Storm signature (incidents/hour scaling with load): stop dispatch, drain minutes, resume at half pace; repeat → halve. Log incident count per wave in the receipt.

**Dead-agent reaping.** 20 minutes of worktree silence (no file mtime change, no process output) → reap the process, reopen the ticket, re-dispatch as a top-up. Hard backstop: the Epoch lease expires at TTL 30 min (`lease.ex:42,70`) — an unreaped agent past lease expiry forfeits the epoch and the loser-typed refusal is recorded. Detached-HEAD worktrees from dead agents are pruned at wave close.

**Integration serialization.** Per epoch cycle (one per minute-tick maximum): ONE `--no-ff` merge into the integration branch, executed only when (a) the main checkout is writer-free, (b) gates pass (mix-test or repo-equivalent). Red gate → reset the integration branch, epoch ends BLOCKED, receipt records the diagnostic; fix waves dispatch next tick. This mirrors xaas's `pr40-merge`-style gated merge branch (§3) and the one-merge-per-rider-run law. Successor epoch starts only on the next tick (`reactor.ex:44-49`) — the cron itself is the serialization fence.

**Receipt telemetry (per agent, one row; aligns with `Receipt` resource attributes `subject / outcome / evidence / sealed_at`, `receipt.ex:65-86`, plus lease fields `worktree / final_head`, `lease.ex:12-13`):**
- `run_id`, `epoch_id`, `agent_id` (worktree N + process id)
- `branch`, `final_sha` (the exact published head, 記)
- `commands[]`: command, exit code, diagnostic path (gate receipts; exit codes preserved on failure)
- `standing`: ALIVE | BLOCKED | PARTIAL_ALIVE | REFUSED_* | UNKNOWN | UNSUPPORTED
- `ratio`: manufactured_lines / total_delivered_lines with attribution evidence (generator receipt or HANDWRITTEN ledger delta); unknown attribution counts as hand-written
- `lease_token`, `lease_expires_at` (capability binding)
- `incidents`: [1302] count, retries used, reaps performed
- `sealed_at` (UTC); appended to an append-only ndjson log (prior art: `~/.zcode/workspace/default/capacity-ride/log.ndjson`).

**Wave-close rule.** The wave ends when in-flight drains to 0 and the single integration merge has landed or been reset; the epoch's `Receipt` (epoch_reactor.ex:255) summarizes agent rows; `Learn` folds standing deltas back into capacity setpoints.
