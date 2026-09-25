# GLM Failover Dispatcher — closing the trigger-automation-gap

Date: 2026-09-18. Session origin: 50-agent audit fan-out on "seamless failover
from Claude Code to xaas ultracode." One dimension of that audit
(`trigger-automation-gap`) found that no automatic dispatcher existed
anywhere in this repo, or in this machine's crontab/launchd, that itself
invokes a zcode/GLM worker without a human typing a command by hand. This
doc and the script it describes close that one specific gap — nothing else
in the audit's larger finding set (see the "Explicitly out of scope" section
below) is touched.

## What this is

`scripts/xaas-glm-failover-dispatcher.sh` is a standalone bash script,
additive only — it does not modify any Ultracode Ash resource, controller,
or plugin template. It:

1. Polls the local XaaS Postgres database directly with a **read-only**
   `SELECT` (never writes to the DB itself):

   ```sql
   SELECT e.id, e.worktree
   FROM ultracode_epochs e
   JOIN ultracode_runs r ON r.id = e.run_id
   WHERE r.provider = 'zcode'
     AND e.state = 'running'
     AND e.lease_token IS NULL
   ORDER BY e.inserted_at ASC;
   ```

   This finds every Epoch the real Oban `:tick` cron
   (`lib/xaas/ultracode/run.ex` → `Xaas.Ultracode.Run.Workers.Tick` →
   `Reactor.run(Xaas.Ultracode.Reactor)`) has already advanced from
   `:expected` to `:running` for provider `"zcode"`, but that
   `EpochReactor`'s `:await_provider` branch is still waiting on — i.e. work
   that is real and ready, but that nothing has claimed yet.

2. For each ready epoch, invokes a headless zcode CLI turn against that
   epoch's worktree:

   ```bash
   cd /Users/sac/dev/zcode-cli && node bin/zcode.js --prompt "/xaas" --cwd "<epoch worktree>" --json
   ```

   That `/xaas` command is the real, already-rendered worker protocol
   (`priv/templates/zcode_plugin/commands/xaas.md.eex`): it is what actually
   calls `claim_next` → does construction work inside the admitted-tool
   fence (`Edit`/`Write`/`Read`/`Grep`/`Glob`/`Task`/`TodoWrite`/`WebFetch`
   only — `Bash`/`git_push`/`publish` remain hard-refused by
   `Xaas.Ultracode.Lease.admit_tool/2`, unchanged by this script) → calls
   `close_candidate` or `refuse` against the real `xaas-execution` MCP
   fabric at `http://localhost:4000/internal-api/execution/mcp`.

3. Skips (logs, does not crash) an epoch whose `worktree` column is null/
   empty, or whose worktree directory does not exist on disk.

4. Sleeps a configurable interval (`--interval SECONDS`, default 30s)
   between polls when run in loop mode.

5. Logs every action with a UTC timestamp to stdout — `DISPATCH`,
   `DISPATCH-OK`, `DISPATCH-FAIL`, `SKIP`, `QUERY-FAIL`, `no ready work`.

6. `--once`: does exactly one poll pass and exits 0, instead of looping
   forever. This is the mode used for testing and for a supervisor
   (launchd/cron) that re-invokes the script on its own schedule instead of
   the script looping internally.

A single failed `zcode` invocation, or a single failed DB query, is logged
and the loop continues — nothing in this script can crash the poll loop on
one bad iteration. There is no retry of a failed invocation beyond letting
the *next* poll pass see the epoch again (if it is still `:running` and
still unleased).

## Real test performed this session

Command run from the repo root:

```bash
cd /Users/sac/xaas && ./scripts/xaas-glm-failover-dispatcher.sh --once
```

Real output:

```
2026-09-18T06:55:39Z [xaas-glm-failover] starting xaas-glm-failover-dispatcher (once=1 interval=30s db=xaas_dev@localhost:5432 zcode_cli=/Users/sac/dev/zcode-cli)
2026-09-18T06:55:39Z [xaas-glm-failover] no ready work (zero provider=zcode running+unleased epochs)
2026-09-18T06:55:39Z [xaas-glm-failover] single pass complete (--once), exiting
```

Exit code: `0`.

This is a genuine, verified negative result, not an untested claim: a direct
query of `ultracode_epochs`/`ultracode_runs` at the same time confirmed the
only two `provider = 'zcode'` rows in the table were in state `missed` and
`failed` (not `running` with a null `lease_token`) — so "no ready work" is
the factually correct answer for the DB's real state at test time, not a
query bug silently matching nothing. The script has not yet been exercised
against a real `running`+unleased `zcode` epoch (none existed in this
database at test time); that path (`DISPATCH`/`DISPATCH-OK`/`DISPATCH-FAIL`)
is implemented and code-reviewed but not yet observed end-to-end against a
live claim.

## Running it under supervision (macOS launchd example)

This is illustrative, not installed — no launchd job has been loaded by
this session. To actually run it as a standing background service:

```xml
<!-- ~/Library/LaunchAgents/com.xaas.glm-failover-dispatcher.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.xaas.glm-failover-dispatcher</string>

  <key>ProgramArguments</key>
  <array>
    <string>/Users/sac/xaas/scripts/xaas-glm-failover-dispatcher.sh</string>
    <string>--interval</string>
    <string>30</string>
  </array>

  <key>WorkingDirectory</key>
  <string>/Users/sac/xaas</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PGHOST</key><string>localhost</string>
    <key>PGPORT</key><string>5432</string>
    <key>PGUSER</key><string>postgres</string>
    <key>PGPASSWORD</key><string>postgres</string>
    <key>PGDATABASE</key><string>xaas_dev</string>
    <key>ZCODE_CLI_DIR</key><string>/Users/sac/dev/zcode-cli</string>
  </dict>

  <key>StandardOutPath</key>
  <string>/tmp/xaas-glm-failover-dispatcher.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/xaas-glm-failover-dispatcher.err.log</string>

  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
```

Load with `launchctl load ~/Library/LaunchAgents/com.xaas.glm-failover-dispatcher.plist`,
unload with `launchctl unload` the same path. `KeepAlive: true` means
launchd restarts the process if the internal `while true` loop's own
container process ever dies — this is the loop-mode invocation (no
`--once`), so the script does its own internal sleep/poll cycle and launchd
only needs to keep the one long-running process alive.

An equivalent cron-driven alternative (single-pass `--once` re-invoked every
minute, letting cron own the scheduling instead of the script's internal
loop) is also valid and arguably simpler to reason about:

```cron
* * * * * /Users/sac/xaas/scripts/xaas-glm-failover-dispatcher.sh --once >> /tmp/xaas-glm-failover-dispatcher.log 2>&1
```

Neither of these has been installed by this session. Installing either is a
standing-configuration change (a persistent background job) and should be a
separate, explicit decision, not a side effect of writing this script.

## Explicitly out of scope / disclosed limitations (do not oversell)

This dispatcher closes exactly one gap: it removes the need for a human to
manually run `claim_next`/`zcode` by hand when a `zcode`-provider epoch goes
`:running`. It does **not** close, and should not be read as closing, any of
the following gaps the same audit found on adjacent dimensions:

- **No automatic retry across zcode-CLI crashes beyond one attempt.** If
  `node bin/zcode.js ...` exits non-zero, this script logs `DISPATCH-FAIL`
  and moves on. The *next* poll pass will see the epoch again only if it is
  still `state = 'running'` with `lease_token IS NULL` — if the failed
  invocation left a lease bound (a partial claim), this dispatcher will not
  see or retry it; that is a separate, real gap (`idempotency-replay-parity`
  in the same audit — a crashed worker's stale lease is reclaimed only by
  `lease_expires_at` passing, which this script does not accelerate or
  monitor).
- **No per-org token.** The invoked `zcode` process uses whatever
  `Authorization: Bearer` value is already baked into
  `~/.zcode/cli/config.json`'s `mcp.servers` entry — today that is the flat,
  shared `INTERNAL_API_TOKEN` dev-server env var, not a per-org
  `mix xaas.internal_api_token issue`-minted token
  (`org-actor-resolution-http-layer` finding). For any real multi-tenant
  deployment this needs a per-org credential swap before this dispatcher (or
  anything like it) is pointed at production.
- **Bash-class verification commands remain unreachable by a leased
  worker.** `mix compile`/`mix test` cannot be run by the worker this
  dispatcher launches — `Xaas.Ultracode.Lease.admit_tool/2`'s hard refusal
  of `Bash` (checked before, and un-overridable by, the per-provider
  `:ultracode_provider_tools` config) is untouched by this script and is not
  something this script attempts to work around
  (`verification-command-parity` finding — a real, still-open gap, not
  solved here).
- **No cross-tenant org scoping on the claim/admit path itself.**
  `claim_next`/`admit_tool`/`close_candidate` have no org check server-side
  today (`multitenancy-org-scoping-gap` finding); this dispatcher inherits
  that exposure exactly as-is — it does not add or remove any org boundary.
- **No observability/alerting wired.** This dispatcher's own stdout log is
  the only signal it produces. It is not wired into
  `Xaas.Ultracode.TickHealth`, `/internal-api/health`, PromEx, or Grafana
  alerting (`monitoring-observability-gap` finding) — if this script itself
  stops running, nothing pages anyone; only manual log-tailing or an
  external process supervisor (launchd `KeepAlive`, cron's own scheduling)
  detects that.
- **No new authority-ceiling, actuation-registry, or Receipt-schema change.**
  This script calls no XaaS code directly — it only queries Postgres
  read-only and shells out to the already-existing `zcode` CLI exactly the
  way a human would. All of the deeper admission-court, receipt-schema, and
  idempotency findings from the same audit pass remain open and require
  their own explicit, separately-authorized code changes inside
  `lib/xaas/ultracode/` — none of that is touched by, or resolved by, this
  script.

## Files

- `/Users/sac/xaas/scripts/xaas-glm-failover-dispatcher.sh` — the dispatcher
  (executable, `chmod +x` applied).
- `/Users/sac/xaas/docs/ultracode/wave-v26.9.17-receipts/glm-failover-dispatcher.md`
  — this document.

No existing Ultracode resource, controller, or plugin template file was
edited to produce either of the above.
