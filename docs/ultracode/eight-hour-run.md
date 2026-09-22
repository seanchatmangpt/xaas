# Ultracode eight-hour run — launch runbook (capacity 5)

**Version:** v26.9.20
**Standing:** PARTIAL_ALIVE — every command in this runbook was executed live in a
bounded smoke on 2026-09-20: campaign `08f5a211` (mechanics + empty wave),
campaign `b997ef78` (stop), campaign `9b9efe2c` (**full real GLM worker wave:
sense → lease → construct → court pass → promote → canonical pass → ALIVE
receipt, §9**), and the §5 OCEL chain executed against that wave's Run
(`7be6069b`: export exit 0, court `valid (4 events, 5 objects)`). What is NOT
yet proven: a full 8-hour campaign — that is the coordinator's run, launched
after this lands.

This is an operator/coordinator runbook. It makes starting the operator-ordered
8-hour, capacity-5 ultracode standing wave a single command, and it specifies
the harness keep-alive automation (§7) verbatim.

**Multi-repo campaigns** (`--repo a,b|all`, target registration, per-repo
OCEL validation, and the multi-repo keep-alive variant): see
`docs/ultracode/multi-repo-run.md` — same budget law, same cuts; this
document's §2/§3/§6/§7 apply to it verbatim.

## 1. The single command

```bash
cd /Users/sac/xaas
export PATH="$HOME/.asdf/shims:$PATH"
mix --version   # MUST print "Mix 1.20.2 (compiled with Erlang/OTP 28)"
mix xaas.ultracode.start
```

No arguments = the standing order: **capacity 5 workers per wave, one wave
every 30 minutes, for 8 hours (16 waves)**. The command is synchronous: it
prints the campaign run id + ledger path, one line per wave, and the terminal
summary; it runs until a budget discharges or you stop it (§5).

Every flag is real and exercised:

| flag | default | meaning |
|---|---|---|
| `--capacity N` | 5 | workers per wave (handed to every wave's dispatcher) |
| `--duration D` | 8h | wall-clock budget; `D` is `<n>h\|m\|s` |
| `--wave-interval D` | 30m | slot grid between waves |
| `--max-waves N` | ceil(duration/interval) | optional cap on the wave-count budget |
| `--goal TEXT` | generated standing-order text | campaign goal prose |
| `--repo ALIAS` | aps | registered repo alias (`config :xaas, :ultracode_repos`) |
| `--suite NAME` | aps-dod | registered verifier suite (admission-validated) |
| `--only a,b` | (all items) | restrict waves to these backlog ids (bounded smokes) |
| `--max-attempts N` | 3 | per-item repair attempts per wave |
| `--base-sha SHA` | repo HEAD | pin the backlog/worktree base |
| `--run ID` | — | resume a `:running` campaign (discharged waves are not repeated) |

### 1.1 The repo registry (what `--repo` may name)

`--repo` names an entry in the validated multi-repo registry
(`Xaas.Ultracode.Repos`): `config :xaas, :ultracode_repos` (the code-seeded
baseline) merged with the durable file `~/xaas/worktrees/ultracode-repos.json`
(written ONLY by the registering task; file wins per alias). Inspect and
extend it with:

```bash
mix xaas.ultracode.repos    # list every entry: status, path, suites, gaps
mix xaas.ultracode.repos --register ALIAS --path /abs/clone \
  [--sensing PROFILE] [--suite NAME] [--canonical-suite NAME] [--worktree-root PATH]
```

Registration validates before writing (alias format, `--path` must be an
existing git work tree, per-entry worktree roots must stay under the global
root). A target may RESERVE its verifier-suite name before the suite exists:
the entry lists its gap (`suite_not_registered`) and `Run` admission fails
closed on it until the suite is registered (`VerifierSuiteRegistered`).
`--sensing` is RECORDED metadata naming the target's sensing profile —
profile-driven sensing itself is owned by `Xaas.Ultracode.Sensing`
(todo_file / jira_dir / failing_tests), and the loop's script-backed aps
stage is wired in `Autonomic.sense/1`. The task never starts the
application — no Repo, no Oban beside a live campaign.

Registered targets (2026-09-20, wave-5 registry law; `nounverb` and `eds`
are sibling wave-5 entries in the config baseline):

| alias | clone | verifier (observed exit 0) | status |
|---|---|---|---|
| `aps` | `~/xaas/worktrees/repos/aps` | `aps-dod` + `aps-canonical` suites | ready |
| `infinite-agentic-cli` | `~/xaas/worktrees/repos/infinite-agentic-cli` | `uv run --frozen pytest tests/test_analysis.py -q` | reserved: suite `infinite-agentic-cli-dod` (sensing `generic-pytest` recorded) |
| `bitstar` | `~/xaas/worktrees/repos/bitstar` | `uv run --frozen pytest test_cli_fixes.py -q` | reserved: suite `bitstar-dod` (sensing `generic-pytest` recorded) |

## 2. The budget law (what makes this ONE run, not an infinite cron)

`Xaas.Ultracode.Campaign` admits a **campaign row** — a real
`Xaas.Ultracode.Run` (goal prefixed `ultracode-campaign/1`, provider `zcode`,
verifier suite validated by `VerifierSuiteRegistered` at create) carrying:

- `deadline_at = now + duration` — the 8h wall-clock budget;
- `max_cycles` — the wave-count budget;
- capacity — recorded in the ledger's `campaign_start` event.

Waves run **serially** on a fixed slot grid; an overrunning wave is followed
immediately by the next (catch-up, never a skip). The campaign row is inert to
the Oban `:tick` Reactor (`NextEpoch.advance_run/1` returns `:no_prior_epoch`
for it; it holds no epochs) — only `Campaign` transitions it:
`:pending -> :running` on start, `:running -> :completed` (standing
`admitted`/`blocked`/`unknown` derived from wave receipts) when a budget
discharges, `:running -> :abandoned` on `stop`. All three edges are admitted by
`Xaas.Ultracode.Validations.RunTransitionAllowed`.

One campaign at a time: a second `start` while one is `:running` is a typed
refusal (`{:campaign_already_running, id}`), never a silent overlap.

## 3. Prerequisites

- **Toolchain** (the toolchain-mixing hazard from `FAILOVER-RUNBOOK.md` §2
  applies verbatim): `export PATH="$HOME/.asdf/shims:$PATH"`, verify
  `mix --version`. Do not run against a `_build` tree another toolchain
  compiled; use the compile lock (`.claude/workflow-compile-lock.sh`) if other
  compiles share your checkout.
- **Postgres**: `xaas_dev` reachable and migrated
  (`PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d xaas_dev -c "select 1;"`).
  `DEV_DB_*` env vars override the postgres/postgres defaults.
- **APS clone + operator dirs** (dev.exs, already configured):
  `~/xaas/worktrees/repos/aps` (the sensed repo),
  `~/xaas/worktrees/runs` (provisioned epoch worktrees),
  `~/xaas/worktrees/tickets` (tickets, campaign ledgers, wave receipts).
- **zcode CLI + a Node ≥ 22.5 for the worker** (`node:sqlite` is required by
  `bin/zcode.js`): `ZCODE_CLI_DIR` defaults to `/Users/sac/dev/zcode-cli`;
  the dispatcher inherits your PATH, so **a PATH whose first `node` is
  v20 (e.g. `/usr/local/bin/node`) kills every worker instantly** with
  `No such built-in module: node:sqlite` (observed 2026-09-20, campaign
  `d6d977be` epoch `bcf50839` → reaped `failed`). A working invocation prefixes
  a dir whose `node` is ≥ 22.5 (homebrew v26 is proven):
  `export PATH="/opt/homebrew/bin:$HOME/.asdf/shims:$PATH"` — then verify
  `which mix` still resolves under asdf shims, or symlink just `node` into a
  private bin dir and prepend that.
- **Auth**: the campaign loop itself is in-process (Ash + the dispatcher's
  direct psql/zcode path), but the WORKER leg is not: workers claim over the
  `xaas-execution` MCP endpoint, whose `RequireInternalApiToken` plug fails
  closed with 503 `internal_api_misconfigured` when the server was started
  without `INTERNAL_API_TOKEN`. Start phx WITH the token matching the
  plugin's `zcode_xaas_token` (observed fail-closed 2026-09-21: every worker
  BLOCKED "cannot reach xaas-execution" until the server was restarted with
  the token). The worker session also needs a project `.mcp.json` in
  `ZCODE_CLI_DIR` registering `xaas-execution` (shape: the plugin cache's
  `.mcp.json`) — headless sessions do not register it from user scope alone.
- **GLM provider quota**: each wave spawns up to `capacity` real zcode/GLM
  sessions; `[1302]`/429 rate-kills are expected occasionally (§6).

## 4. What one wave does, and where everything lands

Each wave is one `Xaas.Ultracode.Autonomic.run/1` pass (identical to
`mix xaas.autonomic.run --repo aps --capacity <N>`):

1. **Sense**: `priv/verifiers/aps_backlog.py` derives work items at an exact
   `base_sha` in a throwaway worktree.
2. **Plan**: per item — a provisioned worktree under `~/xaas/worktrees/runs/`,
   a ticket JSON under `~/xaas/worktrees/tickets/`, and a `Run` + `:running`
   `Epoch` bound to that worktree.
3. **Act**: the dispatcher in directed mode —
   `scripts/xaas-glm-failover-dispatcher.sh --epoch <uuid>` (lock-free,
   exit 0 ok / 1 failed / 75 rate-limited / 3 not-ready) — launches a headless
   `zcode --prompt /xaas` GLM worker that claims the lease via the MCP fabric
   (`Xaas.Ultracode.Lease.claim_next`), constructs in the worktree, and closes
   (`close_candidate`/`refuse`; `Bash`/`git_push`/`publish` hard-refused).
4. **Verify**: `Lease.close/4` runs the fabric verifier suite (`aps-dod`
   court) against the exact closed head; the fabric, not the worker, decides.
5. **Repair**: non-alive receipts append to the ticket and retry the SAME
   worktree, bounded by `--max-attempts`; exhausted items report `blocked`.
6. **Promote**: alive items merge serially (`--no-ff`) into a local
   integration branch; the `aps-canonical` suite runs at that head.
7. **Learn**: everything appends to the ndjson ledger; a terminal
   `receipt.json` is written per wave.

Paths, for campaign run id `<ID>` (first 8 hex = `<ID8>`):

- Campaign ledger (the durable session record):
  `~/xaas/worktrees/tickets/campaign-<ID8>/ledger.ndjson`
- Per-dispatch state/logs: `~/xaas/worktrees/tickets/campaign-<ID8>/dispatch-wave-<n>/`
- Per-wave terminal receipts: `~/xaas/worktrees/tickets/autonomic-<nonce>/receipt.json`
- Ash→OCEL telemetry egress (already live): `<build>/priv/ocel/ash-actions.ndjson`
  (the `Xaas.Telemetry.OcelAshEmitter` handlers write this at boot — observed
  in every campaign boot log).

## 5. Reading status, verifying for real

```bash
mix xaas.ultracode.status              # most recent campaign
mix xaas.ultracode.status --run <ID>   # a specific campaign
```

Prints: row state/standing, budget (`waves_executed/wave_budget`, seconds
remaining), deadline, **in-flight epoch counts (total/leased/unleased)** — the
number the keep-alive automation compares against 5 — and the per-wave digest.

The campaign ledger is the per-wave record; the DB is the per-epoch ground
truth. Cross-check terminality for every epoch the campaign touched (ids from
the ledger's `attempt_start`/`item_done` events):

```bash
python3 - <<'EOF'
import json, subprocess
led = f"/Users/sac/xaas/worktrees/tickets/campaign-<ID8>/ledger.ndjson"
ids = [json.loads(l)["data"]["epoch_id"] for l in open(led)
       if '"attempt_start"' in l]
print(" ".join(ids))
EOF
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d xaas_dev -c "
  SELECT e.id, e.state, e.leased_to, e.final_head, rc.outcome
  FROM ultracode_epochs e
  LEFT JOIN ultracode_receipts rc ON rc.epoch_id = e.id AND rc.evidence ? 'head_verified'
  WHERE e.id IN (<paste ids>);
"
```

An alive wave shows `state = completed` + a `head_verified` receipt. Remember
the §7 finding of the failover runbook: every Oban tick over a still-running
provider epoch seals an `await_provider` receipt with `outcome = alive` —
"done" is `epoch.state = 'completed'` **plus** `evidence ? 'head_verified'`,
never the mere existence of an alive receipt.

**How the whole run is judged validated** (OCEL v2 rule): the run is validated
when (a) the campaign row is terminal (`completed`/`abandoned`) with every
wave's epochs terminal (`completed`/`failed`/`missed` — none `expected`/
`running`), (b) each alive item's receipt carries `head_verified`, and (c) the
run's OCEL v2 log passes the conformance court. (a)+(b) are queryable today
(above). For (c), the OCEL surface landed at `56a2810` (moments after this
runbook's smoke snapshot): export each wave's Run and pass the court —

```bash
mix xaas.ultracode.export_ocel <wave-run-id> --out /tmp/ocel   # Xaas.Ultracode.OcelEgress
mix xaas.ocel_validate /tmp/ocel/<wave-run-id>.ocel.json       # exit 0 = Xaas.Ultracode.Ocel.Validator pass
```

Wave Run ids come from the campaign ledger's `attempt_start` events
(`run_id` field). Validation standing = ALIVE only when (a)+(b)+(c) all hold
for every wave; otherwise PARTIAL_ALIVE with the failing part named. All
three executed live against wave Run `7be6069b` (campaign `9b9efe2c`):
export exit 0, `valid (4 events, 5 objects)`.

## 6. GLM failover notes (from the 2026-09-18/19 receipts)

- **Rate kills** (`Z.AI 429` / `[1302]`): the dispatcher exits 75; the loop
  halves its top-up semaphore, sleeps 30s, retries bounded (`rate_retries` 2),
  then burns an attempt. Isolated incidents are absorbed; a storm (incidents/
  hour scaling with load) = stop, drain minutes, resume at half pace (並 law).
- **Timeouts**: per-zcode-turn kill at 840s (`DISPATCH_TIMEOUT`), below the
  run default `epoch_timeout_seconds` = 900 (a real 5-agent trial had a 310s
  worker; 300s killed it mid-lease — that is why the default is 900 now).
- **Reaper**: an epoch whose worker dies without closing is reaped — lease
  refused (`worker_no_close`) or `mark_failed` — and the attempt is counted.
  Observed live: campaign `d6d977be` epoch `bcf50839` (the node-v20 kill, §3).
- **Workers cannot verify or commit via shell**: `Bash`/`git_push`/`publish`
  are hard-refused by `admit_tool`; the host-side gate (§4 of the failover
  runbook) bounds every dispatcher-launched session. The court verifies; the
  worker never claims done for itself.
- **Honest-worker vs. the judge (observed 2026-09-20, campaign `9b9efe2c`)**:
  a worker that cannot verify its own work correctly closes `partial_alive`
  (the failover doctrine), but the autonomic judge requires `outcome == alive`
  + court pass, so attempt 1 fails even when the court verdict was `pass` —
  attempt 2 (same worktree, repair goal) then closed `alive` + court pass and
  the item finished `done` with `head_verified`. Cost: expect ~one extra
  worker session per item. Budget `--max-attempts` accordingly (2+).
- **Dispatcher concurrency**: directed `--epoch` mode is lock-free and safe to
  run in parallel; the poll mode (`--once`/`--interval`) takes a single-instance
  lock in `STATE_DIR` and drains up to `MAX_DRAIN` (5) per pass.
- **Worker identity**: the dispatcher passes a unique `provider_worker_id`
  per session (attribution; without it zcode memory resurrected one session id).

## 7. Operator cut — how to stop everything

Ordered, least to most drastic:

1. **Graceful (the normal cut)**: `mix xaas.ultracode.stop` (most recent
   running campaign) or `mix xaas.ultracode.stop --run <ID>`. The in-flight
   wave finishes (waves are serial); the loop sees `:abandoned` within ~2s of
   its next poll and exits without further waves. Observed live: stop at
   wave 1/3, loop exited in ~2s, row `abandoned`.
2. **Immediate cut**: SIGINT/SIGTERM the `mix xaas.ultracode.start` process
   (the nohup pid you captured, or `pkill -f xaas.ultracode.start`). The
   campaign row stays `:running` — either resume it later
   (`mix xaas.ultracode.start --run <ID>`) or `stop` it. Already-claimed
   worker leases simply expire (≤ 900s) and are reaped.
3. **The keep-alive automation**: kill = **delete the automation itself**
   (operator cut — never repo code). Max exposure is one 10-minute tick.
4. **The cron path** (only if a `phx.server` is also up): the Oban cron fires
   `autonomic_wave` every 30m and `tick` every 1m inside that VM. To stop
   those waves, stop `phx.server` itself (or, if the failover dispatcher was
   installed as a launchd agent:
   `./scripts/install-glm-failover-launchd.sh uninstall`). A cron wave and a
   campaign wave can coexist (separate integration branches) but duplicate the
   same backlog — prefer running the campaign with the cron path idle.

Nothing in this whole path ever pushes to any git remote; integration is
local `--no-ff` merges into a throwaway branch.

## 8. Harness keep-alive automation (paste verbatim into the scheduler)

Stands up the 8h/48-tick top-up loop the operator ordered. Schedule: every
10 minutes, max 48 runs. `RUN_ID`/`START_TS` are captured at first tick, not
hard-coded.

```text
Ultracode keep-alive tick (10-minute cadence, max 48 runs = 8 hours).

You are a bounded operator surrogate for the ultracode standing wave. Do
EXACTLY the steps below, in order, then end silently. You have no ambient
authority: you run two read-only-or-idempotent local commands, append one
telemetry line, and quit.

1. STATUS. Run exactly:
     cd /Users/sac/xaas && export PATH="/opt/homebrew/bin:$HOME/.asdf/shims:$PATH" && mix xaas.ultracode.status
   (First tick only: also record now as START_TS and the printed campaign id
   as RUN_ID; on later ticks, if the printed campaign id differs from RUN_ID,
   treat the run as finished: go to step 5 with reason "new-campaign".)
   Parse: state (running/completed/abandoned/failed/...), waves executed and
   wave budget from the "budget:" line, seconds remaining, and the "in-flight:"
   line's total/leased/unleased counts.
2. TERMINAL CHECK. If the status command failed, or there is no campaign, or
   state is not "running", or waves_executed >= wave_budget, or
   seconds_remaining <= 0, or START_TS + 8 hours has passed, or this is tick
   48: append the telemetry line (step 4) with "action":"none" and the
   observed reason, then END silently.
3. TOP UP. If in-flight total < 5 and budget remains, run exactly ONE top-up
   pass with the dispatcher's documented single-pass command:
     cd /Users/sac/xaas && ./scripts/xaas-glm-failover-dispatcher.sh --once
   Record its exit code (0 = ok or no ready work, 1 = dispatch failed,
   75 = provider rate limited, 3 = epoch not ready). Never pass --interval,
   never install launchd, never run two --once passes concurrently with
   yourself, never retry a failed pass within the same tick.
4. TELEMETRY. Append EXACTLY ONE ndjson line (create the directory first with
   mkdir -p; writing inside /Users/sac/xaas is permitted ONLY to this exact
   sanctioned gitignored telemetry path — never write anywhere else under
   /Users/sac/xaas, no repo-tree writes):
     /Users/sac/xaas/tmp/ultracode-keepalive/log.ndjson
   Line schema (single line, UTF-8, UTC ISO8601 ts):
     {"ts":"...","kind":"ultracode-keepalive/1","tick":K,"run_id":"...","state":"running","waves_executed":N,"wave_budget":M,"seconds_remaining":S,"in_flight":{"total":T,"leased":L,"unleased":U},"topup":{"ran":true,"exit":0},"action":"topup|none","reason":"..."}
5. END SILENTLY. Produce no prose, no summary, no recommendations. Hard
   prohibitions: never git push anything (force or otherwise), never check
   out or touch main or any branch, never edit or delete files except
   appending to the sanctioned telemetry path
   /Users/sac/xaas/tmp/ultracode-keepalive/log.ndjson, never
   restart or kill any process or server, never run mix test/compile, never
   widen these commands with extra flags. If any command errors, record the
   error in the telemetry line's "reason" field and still end silently.
Hard limits: at most 48 ticks at 10-minute cadence (= 8 hours). Killing this
automation (deleting it from the scheduler) is the operator cut.
```

Reading the telemetry: `tail -f /Users/sac/xaas/tmp/ultracode-keepalive/log.ndjson`.

## 9. Smoke evidence (bounded, 2026-09-20, this branch)

| stage | command (abridged) | exit | observed |
|---|---|---|---|
| A | `mix xaas.ultracode.start --capacity 2 --duration 2m --wave-interval 1m --max-waves 1 --only nonexistent-item --max-attempts 1` | 0 | campaign `08f5a211`, 1 real wave (sense ran at base `5c31d9d0`, 0 items after filter), receipt `autonomic-bc98a3/receipt.json` standing BLOCKED, row `completed`/`:blocked`, 1/1 cycles |
| B | start `--max-waves 3 --wave-interval 30m` in background; then `mix xaas.ultracode.status`; `mix xaas.ultracode.stop` | 0 / 0 / 0 | status: `1/3 waves, 28690s remaining, in-flight 8 (1 leased, 7 unleased)`; stop: `campaign b997ef78 -> :abandoned (1 wave(s) discharged)`; loop observed abandonment in ~2s and exited `stopped after 1 wave(s)`; row `abandoned` in psql |
| C1 | same as C but node v20 on PATH | 0 | worker died instantly (`node:sqlite`), epoch `bcf50839` reaped `failed` — the §3 PATH finding |
| C2 | same as C, node ≥ 22.5, phx DOWN | 0 | worker session booted, found no `xaas-execution` MCP transport, fail-closed BLOCKED without claiming — the §3 phx prerequisite finding (epoch reaped `failed`) |
| C3 | `mix xaas.ultracode.start --capacity 2 --duration 30m --wave-interval 15m --max-waves 1 --only contract-standing --max-attempts 2` (node fixed, phx up) | 0 | campaign `9b9efe2c`: 1 wave, **ALIVE**. Attempt 1: epoch `a1a647d2` completed, court verdict `pass`, receipt `partial_alive` (honest worker, see §6) → repair. Attempt 2: epoch `17ba7e8e` completed, head `ddea432880`, receipt `alive` + `head_verified`; `git -C <worktree> rev-parse HEAD` matches `final_head`; `tests/test_contract_standing.py` committed (real fixtures). Merged `--no-ff` to integration branch `aps-autonomic-adaac0` @ `02508040`; **canonical suite: pass**. Terminal receipt `autonomic-adaac0/receipt.json`: standing **ALIVE**, `human_inputs: 0`. Campaign row: `completed`/`admitted`, 1/1 cycles |

Also exposed and fixed during the smoke (permanent tripwire in
`Xaas.Ultracode.Campaign.past?/2` + tests): `Kernel.>=` on two `DateTime`
structs compares the `:microsecond` tuples first (structural map ordering), so
a campaign with minutes of budget left evaluated "past deadline" and completed
with 0 waves. All DateTime comparisons now go through `DateTime.compare/2`.

## See also

- `docs/ultracode/multi-repo-run.md` — wave-5 multi-repo campaigns: target
  registry, repo-spec planning/rotation, per-repo results and OCEL
  validation, per-target suite prerequisites, and the multi-repo keep-alive
  block.
- `docs/ultracode/FAILOVER-RUNBOOK.md` — the dispatcher, the admission court,
  the 5-agent validation record, and the disclosed limitations this runbook
  builds on.
- `docs/ultracode/c4-architecture.md` — Run/Epoch/Lease/Receipt model.
- `lib/xaas/ultracode/campaign.ex` — the budget law, verbatim.
- `lib/mix/tasks/xaas.ultracode.{start,status,stop}.ex` — the surfaces.
