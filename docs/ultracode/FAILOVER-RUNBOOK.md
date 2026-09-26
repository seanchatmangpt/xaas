# Ultracode Failover Runbook — Claude Code to XaaS/GLM

**Version:** v26.9.22
**Date:** 2026-09-18
**Standing:** PARTIAL_ALIVE — dispatcher exists and was tested against real DB
state (`--once`, exit 0, true "no ready work" negative); construction-side
tool coverage is real but narrower than Claude Code's; several boundaries
below are named limitations, not solved problems. Do not read this document
as "seamless failover" — that claim is not supported by what exists today,
and section 4/6 say exactly why.

This is an operator runbook, not a design doc. It assumes the reader already
knows the Run → Epoch → EpochReactor → Lease → Receipt model
(`docs/ultracode/c4-architecture.md`) and is deciding, in the moment, whether
to fail work over from an interactive Claude Code session to an unattended
zcode/GLM-5.3-flash provider worker against this repo's live dev stack.

## 1. Detecting that Claude Code is unavailable

There is no automated health check for this today — confirmed by grep: no
process in this repo, this machine's user crontab, or launchd polls a
Claude Code session's liveness, and no Grafana rule
(`instrumentation/grafana/alerting/alert_rules.yaml`) references Claude,
Anthropic, or a session heartbeat. "Unavailable" is an operator judgment,
not a monitored signal. Treat any of the following as the trigger to fail
over manually:

- The interactive Claude Code session has ended, hung with no tool output
  for several minutes, or the terminal/session is unreachable.
- A scheduled or on-call task needs work done and no human is at a Claude
  Code session to drive it.
- Anthropic API errors (rate limit, outage, auth failure) are visible in a
  Claude Code transcript or its own status channel.

None of these are wired to anything in this repo. If genuine unattended
failover detection is wanted later, that is the `monitoring-observability-gap`
finding's shape (a new health check + PromEx metric + Grafana alert) — not
built, and not part of this runbook.

## 2. Bringing up Postgres and Phoenix (if not already running)

Check first, before restarting anything:

```bash
# Postgres
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d xaas_dev -c "select 1;"

# Phoenix
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:4000/
```

Postgres (homebrew `postgresql@14`) is expected to already be running and
`xaas_dev` already migrated. If `psql` cannot connect, start it the same way
this machine normally manages it (`brew services start postgresql@14`) —
this runbook does not reinitialize the database.

If Phoenix does not answer with `200`, restart it with the pinned toolchain
from the repo root:

```bash
export PATH="$HOME/.asdf/shims:$PATH"
cd /Users/sac/xaas
mix --version   # MUST print "Mix 1.20.2 (compiled with Erlang/OTP 28)"
                # before proceeding — if it does not, STOP; see the
                # toolchain-mixing warning below.

INTERNAL_API_TOKEN="$INTERNAL_API_TOKEN" MIX_ENV=dev nohup mix phx.server \
  > /tmp/xaas-phx-server-failover.log 2>&1 &

# Poll until it answers (first boot recompiles and is slow, up to ~90s):
until [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:4000/)" != "000" ]; do
  sleep 2
done
```

`INTERNAL_API_TOKEN` must already be exported in the shell that starts
`phx.server` (it is a local dev bearer token used by the internal execution
fabric — see `lib/xaas_web/plugs/require_internal_api_token.ex`). This
runbook does not print its value; treat it the same as any other local
secret and read it from your own shell environment
(`echo $INTERNAL_API_TOKEN`), not from a committed file.

**Toolchain-mixing warning (real, previously happened):** this machine's
default `PATH` resolves `mix`/`elixir` to homebrew (1.19.5), and a stray
asdf 1.18.4-otp-27 has also been run against this same `_build` tree.
Mixing toolchains against one `_build`/`deps` tree corrupts
protocol-consolidation artifacts (`.claude/workflow-lock-guard.md`). Always
`export PATH="$HOME/.asdf/shims:$PATH"` and verify `mix --version` before
any `mix` invocation against this repo.

**Compile-lock discipline (real, already exists — do not reimplement):**
any `mix compile`/`mix test`/`mix run` against this repo should be wrapped:

```bash
cd /Users/sac/xaas
source .claude/workflow-compile-lock.sh
workflow_lock_acquire "<short-label>" 300
# ... mix compile / mix test / mix run ...
workflow_lock_release   # or let the EXIT trap release it
```

This is a real file-based mutex (`.claude/.workflow-compile.lock`, PID
liveness checked, stale locks reclaimed) that exists specifically because
concurrent `mix compile` runs against this repo have previously corrupted
the shared `_build` tree. `phx.server` itself is long-running rather than a
one-shot compile, so it is not wrapped in acquire/release the same way —
but do not start it while another lock-guarded compile/test stage is
actively held; check first with
`.claude/workflow-compile-lock.sh check`.

## 3. Starting the dispatcher for real unattended operation

The dispatcher (`scripts/xaas-glm-failover-dispatcher.sh`, built and tested
this cycle — see
`docs/ultracode/wave-v26.9.17-receipts/glm-failover-dispatcher.md` for the
full build record) polls `ultracode_epochs`/`ultracode_runs` read-only for
`provider = 'zcode'` epochs that are `state = 'running'` with
`lease_token IS NULL`, and headlessly invokes
`node bin/zcode.js --prompt "/xaas" --cwd <worktree> --json` for each one it
finds.

Foreground, one pass (safe to run any time — read-only until it actually
dispatches a worker):

```bash
cd /Users/sac/xaas && ./scripts/xaas-glm-failover-dispatcher.sh --once
```

Real unattended operation — internal loop, 30s poll interval, logs to a
file so it survives the invoking shell closing:

```bash
cd /Users/sac/xaas
nohup ./scripts/xaas-glm-failover-dispatcher.sh --interval 30 \
  > /tmp/xaas-glm-failover-dispatcher.log 2>&1 &
echo "dispatcher pid: $!"
```

Standing install as a per-user launchd agent (`KeepAlive`, `RunAtLoad`) is one
command, not run by this repo on its own — it is a persistent-configuration
decision:

```bash
cd /Users/sac/xaas
./scripts/install-glm-failover-launchd.sh install     # write plist, bootstrap, kickstart
./scripts/install-glm-failover-launchd.sh status      # launchd state, heartbeat age, ALERT
./scripts/install-glm-failover-launchd.sh uninstall
```

Tail the log to watch it work (launchd install logs to
`~/.zcode/failover/dispatcher.out.log`; per-dispatch worker output goes to
`~/.zcode/failover/dispatch-<epoch_id>.log`):

```bash
tail -f /tmp/xaas-glm-failover-dispatcher.log
```

Expected lines: `no ready work`, `DISPATCH mode=claim|reap`, `DISPATCH-OK` /
`DISPATCH-FAIL` / `DISPATCH-TIMEOUT`, `QUERY-FAIL`, `ALERT`.

Behavior (all exercised against the real fabric, see section 7):

- **Single instance.** A `mkdir` lock in `STATE_DIR` (default
  `~/.zcode/failover`) makes a second dispatcher exit; a lock whose pid is dead
  is reclaimed.
- **Drain.** One pass dispatches up to `MAX_DRAIN` (5) epochs, re-querying after
  each, and yields to the next poll if a dispatch made no progress.
- **Reaper.** An epoch whose worktree is missing/null is dispatched from a
  scratch cwd so the worker claims and `refuse`s it through the fabric (it lands
  `failed` with a sealed `refused` receipt) instead of blocking the queue head.
- **Timeout.** Each zcode turn is killed after `DISPATCH_TIMEOUT` (840s), below
  the run default `epoch_timeout_seconds` (now 900, was 300 — a real 5-agent trial
  had a worker take 310s).
- **Host gate.** Each zcode turn is launched with `XAAS_WORKER=1` and
  `XAAS_LEASE_CWD=<canonical cwd>`, which arms the plugin's PreToolUse gate
  (§4). The plugin is a ggen projection: edit `priv/zcode_plugin/ontology.ttl`
  or `templates/`, run `cd priv/zcode_plugin && ggen sync run`, then
  `zcode plugins marketplace update xaas-fabric-marketplace` and
  `zcode plugins update xaas-fabric@xaas-fabric-marketplace` (the marketplace
  is registered at `priv/zcode_plugin/marketplace`; there is no `generated/`
  directory).
- **Attribution.** The dispatcher passes a unique `provider_worker_id`
  (`zcode-dispatch-<host>-<epoch8>-<pid>`) in the prompt; without it, zcode
  memory resurrected an earlier session id and every lease was attributed to it.
- **Stall alert.** Each pass writes `STATE_DIR/heartbeat`. If the oldest
  unleased ready epoch is older than `STALL_ALERT_SECONDS` (600), it writes
  `STATE_DIR/alert`, logs `ALERT`, and posts a macOS notification; the alert file
  is removed when the queue drains.

## 4. What a GLM-backed leased worker can and cannot do today

A zcode/GLM-5.3-flash worker, once it holds a lease
(`admit_tool`-gated, `lib/xaas/ultracode/lease.ex`), is checked against
exactly two hardcoded lists before every tool call
(`admit_tool/2`, lease.ex:285-299):

```elixir
@default_construction_tools ~w(Edit Write Read Grep Glob Task TodoWrite WebFetch)  # line 91
@refused_consequence_tools  ~w(Bash git_push publish)                              # line 93
```

The refusal check runs *before* the operator-configurable
`:ultracode_provider_tools` lookup, specifically so no misconfiguration can
ever re-admit Bash/git_push/publish — "the refusal always wins" (lease.ex
comment at line ~291). A tool that is neither admitted nor refused falls to
`{:error, {:unknown_tool_class, tool}}` — default is deny, not allow.

**CAN do today** (admitted, real, exercised):
- Read/Grep/Glob across the epoch's worktree.
- Edit and Write files inside the worktree.
- Spawn a Task (subagent) and fetch a URL (WebFetch).
- Emit progress via `record_provider_event` (observation only — see §6).
- Call `close_candidate` (outcome: alive/partial_alive/blocked/
  build_broken/unsupported) or `refuse`, both git-head-verified against the
  real worktree at close time.

**CANNOT do today** (hard-refused or structurally unreachable — from this
session's own audit, stated plainly, not softened):
- **Run any shell command** — `mix compile`, `mix test`, `mix format
  --check-formatted`, `npm test`, `pytest`, `cargo test`, or this very
  runbook's own mandated `export PATH=...`/lock-guard/`mix compile`
  sequence. `Bash` is unconditionally refused; the only other admitted-DO
  surface (`actuate/2`, a per-`{resource,action}` registry) is empty by
  default and has no shell-executing action registered anywhere
  (`verification-command-parity` finding). A leased worker therefore has
  **no lawful way to verify its own edits compile or pass tests** before
  calling `close_candidate`. Honest reporting from a worker session in this
  state is `partial_alive` (verifier unavailable) or `blocked` — never a
  claimed `alive` based on an unrun verifier.
- **Commit or push git history through the server's admission court.**
  `Edit`/`Write` change files on disk; none of the admitted tools wraps
  `git add`/`git commit`, and `Bash`/`git_push` are refused by `admit_tool`.
  `close_candidate`'s `final_head` is a *read* (`git rev-parse HEAD`), so
  the close-time head comparison cannot distinguish "worker made real
  committed progress" from "worker only edited files and never committed
  anything" (`git-operations-parity` finding). Commits do happen — see the
  host-side gate below — but they are a host carve-out, not a server
  admission, and `git push` stays refused everywhere.
- **Install dependencies** (`mix deps.get`, `npm install`) — same Bash
  refusal.
- **Publish** anything — `publish` is in the same hard-refused list as
  `git_push`.
- **Search the open web** (`WebSearch`) — absent from both lists, so it
  falls through to the default-deny `unknown_tool_class` branch. Only
  `WebFetch` (fetch a known URL) is admitted.
- **Read Gmail/Calendar/Drive, or drive a browser interactively.** Not
  refused — simply absent from the zcode plugin's MCP config entirely
  (`mcp-tool-surface-parity` finding).

**Host-side gate (PreToolUse), added 2026-09-18.** The `xaas-fabric` plugin
ships `hooks/hooks.json` + `scripts/xaas-gate.mjs`. When a session runs with
`XAAS_WORKER=1` (the dispatcher sets it, plus `XAAS_LEASE_CWD`), every tool
call is decided before it executes; a deny never runs and the worker sees the
reason. Observed: plugin hooks fire in a headless `zcode --prompt` run with the
default `hooks.enabled: false`, so no user-config change is needed. Rules:

- `mcp__*xaas-execution__*` (the lease protocol) is deferred.
- Any other non-Bash tool needs a live saved lease and a real `admit_tool`
  allow from the fabric (zcode `Agent`/`TaskOutput`/`TaskStop` map to `Task`);
  unknown tools such as `WebSearch` are refused by the fabric.
- `Write`/`Edit` targets must real-path-resolve inside the leased worktree and
  never inside `.git`; `Read`/`Grep`/`Glob` cannot touch `~/.zcode`, `~/.ssh`,
  `~/.aws`, `~/.config`, `~/.claude` and similar credential directories.
- `Bash` is an argv allowlist with no chaining, pipes, redirection,
  substitution or globbing: `git add|commit|status|diff|log|rev-parse|show|ls-files`
  inside the worktree (no `push`, `-c`, `-F`, other repos), the plugin's
  `xaas-lease.mjs save|get|clear`, `ls|cat|head|tail|wc` on worktree paths, and
  `pwd|echo`. Exact strings in `lease.verifier`, if a claim ever carries one,
  are also allowed; `claim_next` does not populate it today, so
  `mix compile`/`mix test` remain unavailable to a gated worker.
- It fails closed: unreachable arbiter, unparseable payload, or any internal
  error is a deny. Every decision is appended to
  `<tmpdir>/xaas-fabric/<sha256(cwd)>.gate.ndjson`.

Live evidence: a gated dispatcher run closed `completed`/`alive` with matching
`HEAD` and file while the gate allowed 1 `claim_next`, 5 `git` calls, 1
`Write` and 1 `close_candidate`, and denied a redirect and `xxd`.

Subagents (observed 2026-09-18, zcode-app-cli 3.11.2 with the builtin-provider
alias fix, zcode-cli commit 84b4edc): a subagent launched through the `Agent`
tool ran `curl --version` and **no Bash decision appeared in the gate log** —
a subagent's own tool calls are not routed through PreToolUse (upstream
zai-org/feedback#32). A gated worker could therefore spawn a subagent to step
outside every rule above. The gate now denies `Agent` under `XAAS_WORKER=1`
unless `XAAS_ALLOW_SUBAGENTS=1`; re-probed live, the `Agent` call was refused
with the gate's reason and no subagent started. Fan-out is process-level
(several `zcode --prompt /xaas` workers, §7), and "done" is decided by the
fabric, never by a worker or its subagents.

None of this is a bug to route around. The Bash/git_push/publish refusal is
a deliberate, non-configurable fence per `Xaas.Ultracode.Lease`'s own
moduledoc, and it is not touched, widened, or worked around by the
dispatcher built this cycle. If verification or commit parity is ever
wanted for leased workers, that requires a new, narrow, fixed-argv admitted
capability (analogous to the existing `worktree_head/1` git shell-out with
no attacker-controlled argv) proposed to the repo owner explicitly — not a
loosening of `@refused_consequence_tools` or the provider-tools cond order.

## 5. Verifying a Run completed for real

Do not trust a `close_candidate` outcome string alone. Confirm it against
the database directly:

```bash
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d xaas_dev -c "
  SELECT r.id AS run_id, r.goal, r.state AS run_state, r.standing,
         e.id AS epoch_id, e.cycle, e.state AS epoch_state,
         e.worktree, e.final_head, e.leased_to
  FROM ultracode_runs r
  JOIN ultracode_epochs e ON e.run_id = r.id
  WHERE r.provider = 'zcode'
  ORDER BY r.inserted_at DESC, e.cycle DESC
  LIMIT 20;
"
```

Then pull the sealed receipt for that epoch (the outcome + evidence
actually recorded, and the only durable record of what happened):

```bash
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d xaas_dev -c "
  SELECT epoch_id, subject, outcome, evidence, sealed_at
  FROM ultracode_receipts
  WHERE epoch_id = '<epoch_id from the query above>'
  ORDER BY sealed_at DESC;
"
```

Cross-check `final_head` against the actual worktree, independently of what
the receipt claims:

```bash
git -C '<worktree path from the query above>' rev-parse HEAD
```

A completed, trustworthy Run looks like: `run.state = 'completed'`,
`epoch.state = 'completed'`, `receipt.outcome = 'alive'`, and the
independently-checked `git rev-parse HEAD` matching `epoch.final_head`
*and* `receipt.evidence` showing that head actually advanced past the
epoch's starting SHA. Given §4's git-operations gap, also manually inspect
`git -C <worktree> status --porcelain` and `git -C <worktree> log --oneline
-5` — an `alive` receipt with an unchanged `final_head` is exactly the
signature this runbook's known limitation predicts (edits made, nothing
ever committed), not proof of failure but a case worth a human look before
trusting it as done.

## 6. Real disclosed limitations (named plainly, not smoothed over)

These are open items from this session's own audit of the fabric. None are
fixed by the dispatcher or this runbook, and none should be papered over
when reporting status:

- **No verifier for leased workers.** No lawful path exists today for a
  zcode/GLM worker to run `mix compile`/`mix test` against its own edits.
  Every real `mix test` receipt under `docs/ultracode/` to date was
  produced by a Claude Code session's own local Bash — never by a leased
  provider-worker tool call through this fabric.
- **No commit capability for leased workers.** A worker can edit files but
  has no admitted path to `git commit` them; the close-time head check
  cannot currently tell committed progress from uncommitted edits (§4, §5).
- **No cross-tenant isolation on the claim/admit path.** `claim_next` and
  `find_by_lease` filter by `provider`/`lease_token` only — no `org_id`
  check anywhere on the live path
  (`multitenancy-org-scoping-gap` finding). Do not point this fabric at
  more than one customer's Runs through the same provider string without
  that fix landing first.
- **No per-org token in this dev setup.** The dispatcher and zcode CLI use
  the flat, shared `INTERNAL_API_TOKEN` dev env var, which resolves
  `current_org` to `nil` server-side and cannot use the org-scoped
  `create_run` HTTP surface at all. Any real (non-single-operator)
  deployment needs a `mix xaas.internal_api_token issue --org <slug>`-minted
  token instead (`org-actor-resolution-http-layer` finding) — a credential
  swap, not a code change.
- **No idempotency ledger for crashed workers.** If a worker crashes after
  partial edits but before `close_candidate`, the lease eventually expires
  and `claim_next` can hand the same dirty worktree to a new worker with no
  record of what the first one already changed (`idempotency-replay-parity`
  finding). The dispatcher does not detect or reset this.
- **No alerting if nothing ever claims queued work.** The Oban `:tick` cron
  keeps advancing Runs to `running` unattended even if no worker (human or
  dispatcher) is ever running; no metric, health check, or Grafana rule
  currently notices a growing backlog of unclaimed `running` epochs
  (`monitoring-observability-gap` finding) — this dispatcher, once
  running, is the mitigation, not a monitored guarantee that it stays
  running.
- **The host-side gate is enforced only in dispatcher-launched sessions.**
  Under `XAAS_WORKER=1` the PreToolUse gate (§4) enforces admission on the
  host. An interactive session, or a zcode started without the variable, gets
  no enforcement — the plugin doctrine is then the only fence. Subagent tool
  calls bypass PreToolUse, so the gate denies `Agent` by default. The
  generated worker subagent's tool grant still lists raw `Bash`. The gate is a
  parser-based allowlist, not an OS sandbox: an allowed `git commit` still
  runs the worktree repo's own git hooks.
- **Cost/vendor identity is a real substitution, not just infrastructure.**
  zcode-cli is configured against `zai/glm-5.3-flash` (Z.AI-hosted), not an
  Anthropic model. A timed trivial call took ~16.5s and ~16.7K input tokens
  for a 3-character answer (large, mostly-uncached fixed per-call
  overhead from the plugin's system prompt/tool schema); real per-token
  pricing for GLM-5.3-flash was not established this session, so cost
  parity with Claude Sonnet 5 is unverified, not confirmed equal.

**Bottom line:** this fabric gives a real, tested, unattended path for a
GLM-backed worker to pick up and construct against a queued Epoch when no
human Claude Code session is available. It is not a drop-in replacement for
everything a Claude Code session does — most importantly, it cannot verify
its own work (compile/test) or commit it, and its receipts should be
cross-checked per §5 rather than trusted at face value until the gaps in
this section are closed.

## 7. Validation record: 5 concurrent GLM-5.3-flash agents (2026-09-18)

Five provider-owned Runs (`provider = 'zcode'`, `epoch_timeout_seconds = 900`),
one scratch git worktree each, five `node bin/zcode.js --prompt "/xaas"`
workers launched concurrently against the live fabric. Goal per agent: create
`agent-N.txt` containing exactly `zai-agent-N ok`, commit it, `close_candidate`
ALIVE. Ground truth checked from Postgres and git, not from worker narration:

| agent | wall time | epoch state | closing receipt | `final_head` == worktree `HEAD` | file content exact | tree clean |
|---|---|---|---|---|---|---|
| 1 | 100s | completed | alive, `head_verified` | yes | yes | yes |
| 2 | 121s | completed | alive, `head_verified` | yes | yes | yes |
| 3 | 310s | completed | alive, `head_verified` | yes | yes | yes |
| 4 | 91s | completed | alive, `head_verified` | yes | yes | yes |
| 5 | 106s | completed | alive, `head_verified` | yes | yes | yes |

Five concurrent `claim_next` calls produced five distinct leases (no double
claim). Agent 3 exceeded the old 300s timeout and only finished because the
default is now 900s.

Dispatcher trials, same fabric: stale epoch (missing worktree) ahead of a fresh
one, one `--once` pass — stale epoch reaped to `failed`/`refused`, fresh epoch
`completed`/`alive` with matching `HEAD` and file; unique `leased_to` verified on
two further epochs; stall `ALERT` raised with an unreachable zcode dir and
cleared on drain; a second instance exits on the lock.

Receipts per epoch are not one row. Every Oban tick over a still-`running`
provider epoch seals an await-observation receipt with `outcome = alive` and
`evidence.action_taken = "await_provider"`; only the worker's close carries
`evidence.head_verified`. Decide "the worker finished" from
`epoch.state = 'completed'` plus a receipt with `evidence ? 'head_verified'`,
never from the existence of an `alive` receipt:

```sql
SELECT e.id, e.state, e.leased_to, e.final_head, rc.outcome
FROM ultracode_epochs e
JOIN ultracode_receipts rc ON rc.epoch_id = e.id AND rc.evidence ? 'head_verified'
WHERE e.state = 'completed';
```

## 8. Autonomic definition of done (APS)

The fabric can run a full closed loop that decides "done" independently of the worker: see
`docs/ultracode/wave-v26.9.17-receipts/aps-autonomic-dod-proof.md` (live run, falsifiers,
independent verification, non-claims). Triggers: `mix xaas.autonomic.controls` (falsifiers)
and `mix xaas.autonomic.run --repo aps` (the loop). The dispatcher's directed mode
(`--epoch <uuid>`) is what the loop uses; it is lock-free and safe to run in parallel.

## See also

- `docs/ultracode/c4-architecture.md` — binding Run/Epoch/Lease/Receipt
  architecture this runbook assumes.
- `docs/ultracode/wave-v26.9.17-receipts/glm-failover-dispatcher.md` — the
  dispatcher's full build record, real test output, and supervision
  examples (launchd/cron).
- `.claude/workflow-lock-guard.md` / `.claude/workflow-compile-lock.sh` —
  the compile-lock discipline referenced in §2.
- `lib/xaas/ultracode/lease.ex` — the admission court referenced in §4
  (`admit_tool/2`, `@default_construction_tools`, `@refused_consequence_tools`).
