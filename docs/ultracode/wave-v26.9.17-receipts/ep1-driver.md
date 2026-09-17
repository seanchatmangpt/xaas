# EP1 driver receipt — wave-4 agent 1 — 2026-09-17 — P2 first provider=zcode lease cycle

## Standing: BLOCKED (dev server application died mid-session; falsifier unmeetable, honestly reported)

Timeline (UTC):
- ~18:40 Session start. Server alive (GET probe → 500 fail-closed; log tail showed live Oban tick queries).
- Read context (DESIGN.md, wave1-01/06) + exact contracts (lease_test.exs, execution_fabric_controller_test.exs, lease.ex).
- Read-only DB survey (xaas_dev): 7 runs / 7 epochs / 40 receipts pre-existing. Graveyard finding: 5 runs with
  provider=zcode, ALL their epochs :missed (default epoch_timeout_seconds=300 reaped every attempt); every epoch
  worktree=nil; 33 :alive receipts are EpochReactor-sealed (expected_state/observed_state), zero with head_verified;
  7 :blocked receipts sealed LIVE by the Oban loop on :expected→:missed (evidence keys exactly match
  missed_epochs.ex advance_run/1).
- Locked: worktree created — `git -C /Users/sac/xaas worktree add /tmp/uzc/ep1-worktree -b
  feat/ep1-missed-epoch-receipt fd68647` → HEAD fd68647 ("fix(execution-fabric): normalize standing casing…").
  Both key files present at base: lib/xaas/ultracode/missed_epochs.ex (already seals Receipt on :mark_missed),
  test/xaas/ultracode/missed_epoch_receipt_test.exs (already exists).
- Wrote /tmp/uzc/ep1_admit.exs (Run :create {goal per dispatch, provider "zcode", max_cycles 1,
  epoch_timeout_seconds 3600} + Run :start exact_subject="/tmp/uzc/ep1-worktree", authorize?: false).
- Launched admission under lock as background job (mix run /tmp/uzc/ep1_admit.exs, pid 10012, shares _build/dev
  with the running server; job was still compiling when the crash hit — its eval NEVER executed).
- ~18:47-18:52 MCP handshake attempts (token loaded, length 34, never printed): initialize → connection failure
  (HTTP 000). Server application had died: log line 1205 `[notice] Application xaas exited: shutdown`; line 1206
  `Phoenix.CodeReloader.Server terminating` (`:ets.lookup(XaasWeb.Endpoint, :reloadable_compilers)` — ETS table
  gone, on a reload! request); lines 1105/1186 Oban transaction retries failing with
  `UndefinedFunctionError{module: Xaas.PostgrexTypes, function: :encode_params}` (modules purged mid-flight).
  BEAM pid 32636 (mix phx.server) survives as a shell; NO listener on :4000 (lsof empty, POST → 000).
- Incident attribution (honest): the fatal window coincides exactly with my admission `mix run` recompiling the
  sibling-dirty tree into the SHARED _build/dev while my own curl triggered a live CodeReloader reload on the
  running server — half-swapped beams crashed Oban/Endpoint → app shutdown. My job was the compile side; my curl
  was the reload trigger. No sibling process compiles _build/dev (the visible sibling runs MIX_ENV=test).
- Mitigation taken: STOPPED my admission job (pid 10012) BEFORE its app-start phase — `mix run` without
  --no-start would have bound the now-free :4000 and constituted an accidental unauthorized server restart.
  Lock /tmp/uzc/xaas-mix.lock released. Server NOT restarted (dispatch law). No kill of the server BEAM.
- Post-incident DB verification: ultracode_runs total = 7 (unchanged; zero rows carry my goal string);
  ultracode_receipts total = 40 (unchanged). ZERO DB writes by this agent. Zero leases claimed, zero tokens held.

Falsifier verdict: NOT MET.
- Receipt(provider=zcode, outcome=alive, head_verified=true): impossible — no lease cycle could start; server dead.
- epoch :completed: not reached (my Run was never admitted; eval never ran).
- zero Bash-class admissions: MET vacuously (admit_tool never invoked; no Bash ever admitted or requested).

Intel that survives the incident (verified, for the fleet):
1. The dispatch's named gap is ALREADY CLOSED at fd68647: commit 45fbbb9 (ancestor) sealed the Receipt on the
   :expected→:missed transition; focused test missed_epoch_receipt_test.exs exists; the LIVE Oban loop sealed 7
   :blocked receipts on missed transitions (newest 06:55Z today). PROGRESS.md "item (3)" is closed. Do NOT
   re-implement — any new diff there would be synthetic.
2. head_verified=true is STRUCTURALLY unreachable through the sanctioned flow regardless of this incident: no
   production path ever sets epoch.worktree — Lease.bind_lease (lease.ex:91-110) passes none,
   CreateFirstEpoch (create_first_epoch.ex:32-49) passes none, NextEpoch (next_epoch.ex:96-121) passes none, and
   post-claim Epoch :lease is refused by LeaseAvailable (live lease). lease.ex:290 encodes "worktree comes from
   the epoch row, not the request", so client-supplied worktrees at claim time would reverse an encoded decision —
   a design change for the operator, not a driver workaround. All 7 production epochs have worktree=nil; every
   close would downgrade to :partial_alive (verifier_unavailable=":no_worktree").
3. Operational law for any mix command on this host: it shares _build/dev with the live server — serialize against
   LIVE REQUESTS too, not just sibling agents (the xaas-mix.lock does not cover the server). Admission one-liners
   should use `mix run --no-start` + explicit Repo start, or run from an isolated worktree build.
4. epoch_timeout_seconds default (300) reaped all 5 prior zcode attempts; runs they belonged to remain :running
   forever with :blocked_on_stale_epoch (visible drift by design). Future P2 runs should admit with a generous
   timeout (dispatch used 3600).

Artifacts left in place:
- /tmp/uzc/ep1-worktree (branch feat/ep1-missed-epoch-receipt @ fd68647, no commits — clean base for redispatch)
- /tmp/uzc/ep1_admit.exs (admission script, ready for redispatch under a restarted server)
- Crash evidence: /tmp/uzc/xaas-server.log lines 1105-1211 (see quoted lines above); pid file still names 32636
  (BEAM shell alive, application exited).

Commands + exits: worktree add RC=0; initialize curl HTTP=000; POST probe HTTP=000; lsof :4000 → 0 listeners;
TaskStop on admission job → killed; psql counts 7/40 (unchanged); zero fabric mutations.

What the operator did NOT have to write: this entire driver session (all reads, probes, the worktree, the
admission script, this receipt). What the operator MUST do next: restart the dev server (fresh cut), then
redispatch P2 — the cycle script above is ready; the two structural findings (1)/(2) should steer its goal string.
