# EP1 Observer Receipt — first provider=zcode lease cycle, SEEN FROM OUTSIDE

- Observer: wave-4 agent 2 of 8 (independent; executor is a sibling — no contact, no assistance)
- Date: 2026-09-17. Watch window: 18:26:59Z → 19:03:38Z (35 min nominal + ~8 min extension, extended because the environment died mid-watch; extension used only to attempt capture of run creation)
- Access: read-only throughout. Host psql (user `sac`, trust auth, no secret used or printed) SELECT only; `tail/grep/stat` on /tmp/uzc/xaas-server.log; `lsof`; read-only `git -C /tmp/uzc/ep1-worktree log`. Zero INSERT/UPDATE/DELETE/DDL. Zero HTTP requests. Zero file touches outside this receipt. Nothing restarted.

## Environment facts discovered (shape only, no secrets)

- Server: Phoenix app `xaas` 26.8.21, dev mode, beam.smp listening 127.0.0.1:4000 at watch start; log /tmp/uzc/xaas-server.log has NO timestamps (dev console format `[$level] $message`) — log lines were time-anchored via DB clocks and embedded epoch-millis.
- DB: native Homebrew Postgres 14.19 on host :5432 (NOT the compose `db` service — compose is down: "service db is not running"). DB clock = UTC; ultracode naive timestamps are UTC (cross-checked via millis goal stamp 1789628075777 = 06:54:35.777Z matching inserted_at).
- Tick engine: `Xaas.Ultracode.Run.Workers.Tick` via Oban, per-minute cadence, jobs completed 18:22:00–18:28:00 every minute. Executor surface: `POST /internal-api/execution/mcp` (seen in log).
- Schema: ultracode_runs(provider, state, standing, cycle, max_cycles, epoch_timeout_seconds, last_expected_epoch_at, last_completed_epoch_at, ...), ultracode_epochs(cycle, exact_subject, state, expected_at, started_at, completed_at, lease_token, lease_expires_at, leased_to, worktree, final_head, run_id), ultracode_receipts(subject, outcome, evidence jsonb, sealed_at, epoch_id). Also present: actuation_intents/receipts (authority jsonb, replay_token, hashes), OCEL 5-table set (ocel_events/objects/event_objects/object_objects/object_state_deltas).

## Observation timeline (all times UTC, from DB/log/socket)

| ts | observation |
|---|---|
| 18:26:59 | Session start. Server up on :4000; per-minute ticks live; log shows missed-epoch sweep queries at 18:21:01 and 18:25:58 |
| 18:27 | DB baseline: 7 pre-existing runs, ALL provider=zcode or blank, ALL state=running, standing=unknown, started 06:33–06:54Z; none matches the executor's goal ("missed-epoch receipt-coverage gap") |
| 18:28:00 | LAST tick job ever scheduled+completed (oban id 114) |
| ~18:29:10 | APP DEATH (log mtime frozen here): `Xaas.PostgrexTypes.encode_params/2` undefined (module unavailable) → `Oban.Repo exhausted transaction retries` → `{Oban.Registry, {Oban, Oban.Sonar}}` GenServers terminating → Phoenix CodeReloader ETS crash on `{:reload!, XaasWeb.Endpoint, ...}` from client PID → `[notice] Application xaas exited: shutdown`. :4000 stops listening. NOT caused by observer (zero writes/HTTP/file-touches) |
| 18:29:47–18:51:57 | 15 polls (~85–90s cadence): 0 new runs, 0 epochs, 0 receipts; server down every poll; log mtime frozen at 18:29:10Z |
| 18:53:36 | /tmp/uzc/ep1-worktree FIRST EXISTS — executor demonstrably alive and preparing, despite server down |
| 18:53:36–19:03:38 | 8 more polls: server never returned (:4000 down, log frozen); executor's run NEVER created; receipts total constant at 40; ocel_events constant at 0 |

## Verification verdicts

(a) Receipts with provider=zcode, outcome=alive, head_verified=true — **NOT VERIFIED (episode-absent)**. The run was never created; 0 receipts during watch. DB-wide: 40 receipts exist, all sealed ≤06:55Z against pre-existing test epochs; evidence jsonb keys are ONLY {epoch_timeout_seconds, expected_at, expected_state, observed_state} — no provider, no head, no head_verified field exists in ANY receipt ever written. The receipt contract the task expects does not yet exist in the data (consistent with the run goal targeting a receipt-coverage gap).

(b) Provider-event trail free of Bash/git_push-class admissions — **PASS (vacuously, with DB-wide corroboration)**. No provider-event trail ever came into existence. DB-wide: actuation_intents (4) and actuation_receipts (4) are Sep-9 Library.Curation/Checkout actions, all succeeded, no Bash/git_push class anywhere; ultracode receipts contain none.

(c) final_head is a real commit — **NOT VERIFIED (no claim exists)**. No epoch row was created during the watch, so no final_head was ever recorded. For the record, read-only `git -C /tmp/uzc/ep1-worktree log --oneline -3` at close shows real commits: `fd68647 fix(execution-fabric): normalize standing casing at the transport — honest ALIVE was silently downgraded`, `37aaa85 test(execution-fabric): Chicago qualification of the HTTP surface over real Postgres`, `fd829dc feat(ultracode): ActuationLease provider-pull edge on the existing Run/Epoch/Receipt seam`. These are worktree facts, NOT DB-verified head facts.

(d) No manual/forced Reactor or state transitions — **PASS (for what ran)**. Frozen log contains 0 UPDATE/DELETE statements against ultracode tables (grep across all 1219 lines) — the only ultracode mutations ever visible are app-internal. Per-minute tick cadence healthy and all-completed 18:22–18:28; after app death, zero transitions of any kind occurred (nothing could transition — no executor, no ticks). Missed-epoch sweep queries (18:21:01, 18:25:58) correlate with tick-driven sweeps. All 7 old epochs sit in state=missed — reaped by the sweep, not forced.

(e) OCEL events landed for the episode — **FAIL (nothing landed; nothing could)**. ocel_events=0, ocel_objects=0, constant all watch. The episode never started, so no events exist to confirm.

## Anomalies (findings, honestly recorded)

1. **ENVIRONMENT CRASH DURING WATCH (primary anomaly)**: app died ~18:29:10Z, ~2 min into the watch, BEFORE the executor's run existed. Chain: Xaas.PostgrexTypes module unavailable (hot-reload/type-module damage) → Oban transaction retries exhausted → Sonar/peers terminating → CodeReloader ETS crash on a reload! request → application exit. Server did not recover within the window. Observer caused nothing (no HTTP, no writes, no file touches; first and only log activity attributable to my session is nothing — log froze at crash).
2. **EPISODE RUN NEVER MATERIALIZED**: the provider=zcode "missed-epoch receipt-coverage gap" run has zero DB footprint (no run, epoch, lease, receipt). Executor showed external liveness (worktree appeared 18:53:36Z, holding 3 real commits) but its lease cycle Executed NOTHING inside the watch window. Executor-claimed vs DB-observed: any executor claim of a completed lease cycle for ep1 is UNSUPPORTED by the DB as of 19:03:38Z.
3. **PRE-EXISTING DEBT (context, not this episode)**: 7 earlier zcode runs (06:33–06:54Z) all stuck state=running / standing=unknown with cycle-0 epochs reaped to :missed; runs never reached a terminal standing. Receipt evidence contract lacks provider/head_verified fields entirely — the exact coverage gap the run goal names.
4. **Stale-state hazard**: oban max scheduled_at = 18:28:00 — no jobs queued; on server restart the 7 zombie :running runs will be the first thing the sweep meets. Their standing should not be mistaken for this episode's.

## Final episode standing, SEEN FROM OUTSIDE

- Independently verified: the lease cycle did NOT execute during 18:27–19:03Z; therefore Verified/ALIVE cannot be attributed to ep1 from the DB by any observer.
- The executor is alive (worktree activity) but blocked by the dead server; the run cannot be created, no lease can be granted, no tick exists to drive epochs.
- Episode standing (observer's verdict): **BLOCKED** — environment server down since 18:29:10Z; episode has zero DB footprint.
- If the executor later claims ALIVE for this window: it must be reconciled against this receipt (DB shows run created after 19:03:38Z at the earliest, outside my watch).

## Observer receipt discipline

- Commands used: psql SELECT (~40 queries), tail/grep/stat on server log, lsof, docker ps (read-only), git -C log (read-only), ls -d existence check, date.
- What the operator did not have to write: this entire evidence record (43 min of polling, crash forensics, verdicts) was manufactured by the observer agent; zero mutations to any shared surface.
- Falsifiers attempted: (i) searched for the run under any provider/goal (all 7 runs inspected individually); (ii) cross-checked timestamp semantics (UTC confirmed two independent ways) to rule out "run exists but timestamps misread"; (iii) checked oban for late-scheduled jobs (none); (iv) checked for log-buffer truncation (log frozen, not rotated); (v) confirmed my own non-involvement (no writes/HTTP possible from my command set).
