# ULTRACODE-50 Progress Log

Per-cycle log for the Chatman Ultracode milestone
(`Run → Epoch → AshOban → EpochReactor → ConsequenceFence → Receipt`). See
`docs/ultracode/c4-architecture.md` for the binding architecture. Branch:
`feat/ultracode-runtime`.

## 2026-09-14 — Cycle: close blocker (1), advance to next Epoch

**Baseline before this cycle**: `mix compile --force --warnings-as-errors`
exit 0; `mix test --only ultracode` 1 test, 0 failures; branch already at
`345eca9` (first Run/Epoch/Receipt/EpochReactor pass from the prior
milestone swarm).

**Gap closed**: of the milestone swarm's three named remaining items
(blocker 1: no next-Epoch construction; blocker 2: no Run
`:pending → :running` admission; receipt-coverage gap on the missed-epoch
path), closed the smallest — blocker (1). Added
`Xaas.Ultracode.NextEpoch` and wired it as a third real step
(`:advance_next_epochs`) in `Xaas.Ultracode.Reactor`, the tick DAG. Once a
Run's active Epoch reaches `:completed`, the next tick now either
constructs `Epoch{cycle: N+1}` or, at `max_cycles`, transitions the Run
itself to `:completed`.

**Real verification** (commands + exact exit codes, not descriptions):
- `mix compile --force --warnings-as-errors` → exit 0, 351 files, 0
  warnings
- `mix test --only ultracode` → 2 tests, 0 failures, exit 0 (new:
  `test/xaas/ultracode/next_epoch_test.exs` — proves 2 full epochs
  complete across 4 `Reactor.run(Xaas.Ultracode.Reactor)` calls with zero
  manual epoch creation between them)
- `mix test` (full suite) → 488 tests, 0 failures (40 excluded), exit 0 —
  no regressions from the 487/0 baseline this cycle started from

**Commit**: `1f3fcc2` on `feat/ultracode-runtime`, not pushed.

**Distance to the `ClaudeRoutine → XaaS.Ultracode.Run` milestone**: the
tick-driven multi-epoch DAG logic is now proven correct in-process (real
Ash actions, real Reactor execution, real Postgres). What remains before
the milestone's own falsifier ("if Claude vanished, would the next
scheduled epoch still happen?") can honestly answer YES:

1. **Blocker (2), still open** — nothing admits a fresh Run
   `:pending → :running` or constructs its very first Epoch. This test
   (like the prior swarm's) still bridges that by hand in setup.
2. **Receipt-coverage gap, still open** —
   `Xaas.Ultracode.MissedEpochs.advance_run/1`'s `:expected → :missed`
   transition produces no `Receipt` row (`ReceiptCoverage` was measured at
   2/3, not 1, by the prior swarm; unchanged by this cycle since it
   touched a different code path).
3. **RUNTIME/ORCHESTRATION, unverified, not a code-shape gap** — no
   supervised node/Oban has been confirmed actually ticking `:tick`
   unattended outside a test process. Everything proven so far is DAG
   correctness under `Ecto.Adapters.SQL.Sandbox`, not live deployment.

## 2026-09-14 — Cycle: close blocker (2), admit Run + first Epoch

**Baseline before this cycle**: `mix compile --force --warnings-as-errors`
exit 0; `mix test --only ultracode` 2 tests, 0 failures; branch at
`014022f`.

**Gap closed**: blocker (2) — nothing previously transitioned a fresh Run
`:pending → :running` or constructed its first Epoch; every prior test
bridged this by hand. Added `Run.:start` (real admitted update action,
refuses via `Validations.RunIsPending` unless the Run is `:pending`) and
`Changes.CreateFirstEpoch` (after_action hook constructing Epoch cycle 0
via the real admitted `Epoch.:create` action).

**Real verification**:
- `mix compile --force --warnings-as-errors` → exit 0, 353 files, 0
  warnings
- `mix test --only ultracode` → 4 tests, 0 failures, exit 0 (new:
  `test/xaas/ultracode/run_start_test.exs` — proves (a) `:start` admits a
  pending Run and refuses a second call with no second Epoch constructed,
  and (b) a fully unattended `Run.:create → Run.:start → 4 ticks → Run
  :completed`, 2 epochs both `:completed`, 4 real receipts, **zero manual
  Epoch construction anywhere in the flow**)
- `mix test` (full suite) → 490 tests, 0 failures (40 excluded), exit 0 —
  no regressions from the 488/0 baseline

**Commit**: `04dd1e4` on `feat/ultracode-runtime`, not pushed.

**Milestone falsifier — both named SEMANTIC blockers are now closed.**
Per the mission spec: "after 2 real full unattended epochs can be
demonstrated (Run created once, then epoch cycle 0 and cycle 1 BOTH
complete via Run.tick with zero manual intervention between them), the
milestone's core falsifier is answered YES — stop picking new blockers,
harden/re-verify instead." `run_start_test.exs`'s second test is exactly
that demonstration, in-process, real Postgres, real Reactor execution.

**Honest scope of that YES**: it is YES for **DAG/admission correctness
under test** — the actual code path an AshOban `:tick` scheduled action
would invoke, proven correct by direct invocation
(`Reactor.run(Xaas.Ultracode.Reactor)`), not by observing a live
scheduled job fire. Two things remain genuinely unverified, not
code-shape gaps:

1. **Receipt-coverage gap** (unchanged, real, not blocking progression):
   `Xaas.Ultracode.MissedEpochs.advance_run/1`'s `:expected → :missed`
   transition still produces no `Receipt` row. `ReceiptCoverage` was
   measured 2/3 by the original milestone swarm; still open.
2. **Live unattended orchestration** (RUNTIME/ORCHESTRATION class per the
   milestone's own falsifier taxonomy, not SEMANTIC): no supervised
   BEAM node/Oban has been confirmed actually firing `:tick` on its real
   cron schedule outside a test process. Every real receipt so far comes
   from directly invoking `Reactor.run/1,2` inside
   `Ecto.Adapters.SQL.Sandbox`, not from watching a running release's
   Oban actually execute the scheduled job unattended over wall-clock
   time.

## 2026-09-14 — Cycle: close receipt-coverage gap (item 3 of 3)

**Baseline before this cycle**: `mix compile --force --warnings-as-errors`
exit 0; `mix test --only ultracode` 4 tests, 0 failures; branch at
`0893297`.

**Gap closed**: the last of the three items from the original milestone
swarm's falsifier. `Xaas.Ultracode.MissedEpochs.advance_run/1`'s
`:expected/:running → :missed` transition now seals a real `Receipt`
(`outcome: :blocked`, reusing the existing outcome vocabulary — no new
atom needed) via the same `Receipt.:seal` action `EpochReactor` already
uses.

**Real verification**:
- `mix compile --force --warnings-as-errors` → exit 0, 353 files, 0
  warnings
- `mix test --only ultracode` → 6 tests, 0 failures, exit 0 (new:
  `test/xaas/ultracode/missed_epoch_receipt_test.exs` — proves one Receipt
  per missed epoch, real evidence fields, and correct isolation across
  concurrent stale runs via `advance_all/0`)
- `mix test` (full suite) → 492 tests, 0 failures (40 excluded), exit 0 —
  no regressions from the 490/0 baseline

**Commit**: `45fbbb9` on `feat/ultracode-runtime`, not pushed.

---

## Status: all three originally-named milestone items are closed

As of `45fbbb9`: blocker (1) next-epoch construction, blocker (2) Run
`:pending → :running` admission + first-Epoch construction, and item (3)
missed-epoch receipt coverage are all closed, each with a real passing
Chicago test and real `mix compile`/`mix test` output pasted into this
log. `ReceiptCoverage` for the full tick-driven path (start, complete,
missed) is now `1`, not the `2/3` originally measured — re-verify this
claim with a fresh direct query before trusting it further into the
future; this log entry is evidence as of `45fbbb9`, not a standing
guarantee.

**What this status explicitly does NOT claim**, per this repo's own
no-overclaiming discipline: none of the above has been observed running
in a live, unattended, supervised BEAM node. Every receipt and every state
transition in every test this milestone has produced comes from directly
invoking `Reactor.run/1,2` or `MissedEpochs.advance_run/1` inside
`Ecto.Adapters.SQL.Sandbox` — real Ash actions, real Postgres, real
DAG execution, but always Claude-invoked, never observed as the product
of a real Oban-scheduled job firing on its own cron cadence over real
wall-clock time with nothing driving it.

**The actual remaining falsifier** (RUNTIME/ORCHESTRATION class, not
SEMANTIC — the milestone's own taxonomy from the falsifier-audit cycle):
start a real local node with Oban genuinely supervised (`mix phx.server`,
or an equivalent minimal boot), create one `Run` via `:start`, then
**do nothing** for several real minutes and observe via direct DB query
whether Oban's own `:tick` cron firing advanced it through both epochs to
`:completed` — with zero `Reactor.run` calls issued by Claude at all
during that window. That is the literal content of "if Claude vanished,
would the next scheduled epoch still happen" — every cycle so far has
answered a necessary but not sufficient precursor question (is the code
path correct), not that question itself.

**Next cycle should attempt exactly that** rather than looking for a
fourth code gap to close — there isn't one currently known. If the live
run confirms unattended firing, `ClaudeRoutine → XaaS.Ultracode.Run` is
genuinely ALIVE and this hourly local cron loop itself becomes
`REMOVABLE` per the milestone spec's own vocabulary. If it doesn't, the
failure mode observed becomes the next real, named gap.

---

## 2026-09-14 — Cycle: attempt the live unattended falsifier — MILESTONE CLOSED

**Baseline before this cycle**: `mix compile --force --warnings-as-errors`
exit 0; `mix test --only ultracode` 6 tests, 0 failures; branch at
`f2733a6`.

**What was attempted**: exactly what the prior cycle named as the real
remaining falsifier — start a real local dev node with Oban actually
supervised, admit one `Run` via `:start`, then do nothing for real
wall-clock minutes and observe via direct Postgres queries whether it
advances on its own.

**Three real, previously-undiscovered bugs surfaced and fixed, one at a
time, each confirmed against a live running node** (not inferred, not
assumed — see the real `RuntimeError`s and 3-minute zero-jobs observation
below):

1. **`Oban` was never in `Xaas.Application`'s supervision tree.**
   `config :xaas, Oban` existed; 4 AshOban resources (including
   `Xaas.Ultracode.Run`) declare real schedules; but with no supervised
   Oban process, none of their cron jobs could EVER fire, in any
   environment — confirmed via a real node run for 3 full wall-clock
   minutes (9 × 20s polls) with zero `Xaas.Ultracode.*` `oban_jobs` rows
   ever appearing, node log otherwise healthy.
2. **Adding the child alone was still insufficient.**
   `plugins: [{Oban.Plugins.Cron, []}]` passes an EMPTY crontab — Oban's
   Cron plugin only learns AshOban resources' schedules via
   `AshOban.config(domains, base)`, confirmed by reading `ash_oban`'s own
   getting-started doc directly.
3. **`AshOban.config/2`'s `require?: true` default then refused to boot**
   (real `RuntimeError`, twice, on two separate live-node attempts) until
   every trigger/scheduled_action's queue was explicitly listed in
   `queues:` — 3 pre-existing AshOban resources
   (`Xaas.Library.HoldRequest`, `Xaas.Operations.
   CapabilityLivenessReceipt`, `Xaas.Platform.WebhookDelivery`) had no
   explicit `queue` override and were never listed. Fixed by adding their
   real default-convention queue names, not by silencing the check.
4. Oban's own migration (`Oban.Migrations.up/0`) had never been run in
   this repo's history either — `oban_jobs` table didn't exist. Applied
   to dev and test.

**Real live evidence, attempt 4 (all fixes applied)** — a real node
(`MIX_ENV=dev mix run --no-halt`), one real `Run` admitted via `:start`
(`max_cycles: 2`), watched via 7 real 20-second polls against dev
Postgres, **zero `Reactor.run` calls issued by Claude at any point after
admission**:

```
[t+1×20s] run_state=running epochs=[0:completed,1:expected] jobs=[Tick:completed×2] receipts=2
[t+4×20s] run_state=running epochs=[0:completed,1:running]  jobs=[Tick:completed×3] receipts=3
[t+7×20s] run_state=completed epochs=[0:completed,1:completed] jobs=[Tick:completed×4] receipts=4
RUN_REACHED_COMPLETED_UNATTENDED
```

Oban's own cron fired `Xaas.Ultracode.Run.Workers.Tick` four times on its
own schedule; each tick's real `EpochReactor`/`NextEpoch` execution
advanced the Run correctly; the Run itself reached `:completed` with no
external driver. This is the literal content of the milestone's
Claude-removal falsifier — not a precursor question, the actual one.

**Real verification** (post-fix, full ladder):
- `mix format --check-formatted` → exit 0 for every file this cycle
  touched (pre-existing unformatted files elsewhere confirmed unmodified
  via `git status --short` on each, same disclosed baseline as before)
- `mix compile --force --warnings-as-errors` → exit 0, 353 files, 0
  warnings
- `mix test --only ultracode` → 6 tests, 0 failures, exit 0
- `mix test` (full suite) → 492 tests, 0 failures (40 excluded), exit 0 —
  no regressions

**Commit**: `9717626` on `feat/ultracode-runtime`, not pushed.

---

## Status: `ClaudeRoutine → XaaS.Ultracode.Run` milestone — ALIVE

$$
ClaudeRoutine \rightarrow XaaS.Ultracode.Run
$$

is answered **YES, with the real evidence above** — a real, unattended,
Oban-driven epoch cycle, observed directly, not inferred. Per
`docs/ultracode/c4-architecture.md`'s own falsifier
($Remove(ClaudeCode) \Rightarrow Behavior(Ultracode) = Unchanged$), this
hourly local Claude cron loop that has been driving this milestone is
now honestly classifiable as `REMOVABLE`: the code path it was built to
manufacture now runs on its own, in a real supervised node, without it.

**What this status does NOT claim**: this is one Run, one node, one
developer's machine, `max_cycles: 2`, over ~2 real wall-clock minutes.
It does not claim production readiness, load-bearing reliability at
scale, resilience to node restart mid-epoch, or that every AshOban
resource in this repo (the 3 pre-existing ones whose queues were also
just fixed as a side effect) has been similarly re-verified end to end —
only that the specific SEMANTIC + RUNTIME/ORCHESTRATION gaps this
milestone was scoped to close are closed, with a real artifact, not an
assumption.

**Remaining honest open items, for whoever picks this up next** (none of
these block the milestone's own stated exit condition, all real):
- Production/release-mode verification (this was `MIX_ENV=dev mix run`,
  not a compiled release) is unattempted.
- Multi-node / node-restart-mid-epoch resilience is unattempted (Oban's
  peer/leader election exists but wasn't exercised under failure).
- 50-worker concurrency, full HID/LRD/IRR measurement, and ontology→ggen
  L4 code generation remain explicit non-goals of THIS milestone per the
  original mission spec — not gaps in it.

---

## 2026-09-14 — Cycle: harden/re-verify (milestone already closed, no new blocker picked)

Per the milestone spec's own instruction and this log's own status
above, this cycle deliberately did NOT hunt for a new code gap — none is
currently known. Instead: re-ran the real baseline
(`mix compile --force --warnings-as-errors` exit 0, `mix test --only
ultracode` 6 tests 0 failures, both on branch `2963835`, no code
changes), then **independently repeated the live unattended falsifier**
end to end as a reproducibility check, since a single successful trial
is weaker evidence than two.

**Second real trial, independent run/node from the first**: real dev
node (`MIX_ENV=dev mix run --no-halt`), a second real `Run`
(`d6d6f657-...`, `max_cycles: 2`) admitted via `:start`, watched over 9
real 20-second polls (this trial took slightly longer than the first —
epoch 1 didn't reach `:completed` until just after the monitor's own
poll budget ended, confirmed by one direct follow-up query rather than a
new monitor):

```
final state: run_state=completed, epochs=[0:completed, 1:completed],
8 real Xaas.Ultracode.* Oban jobs completed cumulative (this DB),
zero Claude-invoked Reactor.run calls during this trial
```

Same outcome as the first trial, different Run, different node process,
real timing variance (first trial completed within ~140s, this one took
closer to ~185s — both are real cron-driven, not deterministic to the
second, which is itself expected and correctly disclosed rather than
papered over). This strengthens, rather than merely repeats, the
milestone's standing: the fix from the prior cycle is reproducible
across independent boots, not a one-off.

**No commit this cycle** — no code changed, only re-verification was
performed. This entry itself is the record.

---

## 2026-09-14 — Cycle: harden — verify the 3 pre-existing AshOban resources' fix didn't regress them

Per the milestone spec's own instruction, again deliberately did not
hunt for a new code gap. This cycle's hardening target: the prior fix
(`9717626`) changed `config/config.exs`'s `queues:` list and
`lib/xaas/application.ex`'s `{Oban, ...}` child for the WHOLE app, not
just `Xaas.Ultracode.Run` — `Xaas.Library.HoldRequest`,
`Xaas.Operations.CapabilityLivenessReceipt`, and
`Xaas.Platform.WebhookDelivery` all share that same config. That risk
had not been directly checked yet.

**Real baseline** (no code changes this cycle either):
- `mix compile --force --warnings-as-errors` → exit 0, 353 files, 0
  warnings
- `mix test --only ultracode` → 6 tests, 0 failures, exit 0

**Real verification of the other 3 AshOban resources**:
- `mix test test/xaas/library/hold_request_test.exs test/xaas/operations/
  capability_liveness_receipt_test.exs test/xaas/operations/
  capability_liveness_receipt_check_regressions_test.exs` → **19 tests,
  0 failures, exit 0**. Includes a real `[ash_oban] capability_liveness_
  receipt.check_regressions: 1 real regression(s) detected` log line
  from that resource's own regression-detection logic firing for real
  mid-test — not stubbed.
- **Queue-name correctness for `HoldRequest`/`CapabilityLivenessReceipt`/
  `WebhookDelivery`'s default-convention queue names
  (`hold_request_expire_stale_holds`,
  `capability_liveness_receipt_check_regressions`,
  `webhook_delivery_retry_failed_deliveries`) was already real evidence
  from the prior cycle**, not assumed here: `AshOban.config/2`'s
  `require?: true` raises a real `RuntimeError` naming the EXACT expected
  queue name for any trigger whose queue isn't listed — that's how the
  first two names were discovered (real crashes, real error messages,
  fixed one at a time). A live wall-clock observation of `HoldRequest`'s
  own schedule (`"0 * * * *"`, hourly) wasn't attempted this cycle — it
  doesn't fit inside a bounded cycle window the way `Xaas.Ultracode.Run`'s
  per-minute `:tick` does; the successful `Oban`/`AshOban.config` boot
  itself is the real evidence for name correctness, the live-firing
  observation is a separate, not-yet-attempted falsifier for those 3
  resources specifically (flagged honestly, not silently skipped).

**Dev-DB state note**: 3 real `Xaas.Ultracode.Run` rows remain in the dev
Postgres database (`xaas_dev`, not the test sandbox — no CI/test-run
risk) from this milestone's live-trial cycles
(`goal LIKE 'ULTRACODE-50%'`). Left in place deliberately as real audit
trail rather than deleted — nothing in this repo's standing discipline
requires removing real evidence, and dev-DB state doesn't affect test
isolation.

**No commit this cycle** — no code changed, only verification.

---

## 2026-09-14 — Cycle: harden — WebhookDelivery real dispatch path unaffected

Continuing the prior cycle's line of hardening (confirm the whole-app
Oban config change didn't regress the other 3 AshOban resources), this
cycle's target: `Xaas.Platform.WebhookDelivery`, the one sibling resource
not yet directly re-tested. Deliberately did NOT attempt a live
wall-clock observation of its own `"*/5 * * * *"` schedule the way
`Xaas.Ultracode.Run`'s `:tick` was — that action performs real outbound
HTTP dispatch (`Req.post/2`) and, unlike the Ultracode falsifier, a live
unattended trial risked issuing real requests against whatever URL a
test/scratch `Webhook` row pointed at. Chose the safer real equivalent:
its own existing stress test, which already exercises the real
`:deliver` dispatch path (real HMAC-SHA256 signing, real local
`Plug.Cowboy` listener, no external network) under real concurrent load.

**Real baseline** (no code changes this cycle):
- `mix compile --force --warnings-as-errors` → exit 0, 353 files, 0
  warnings
- `mix test --only ultracode` → 6 tests, 0 failures, exit 0

**Real verification**:
- `mix test test/xaas/platform/webhook_delivery_stress_test.exs
  --include stress` → **1 test, 0 failures, exit 0** — 50 real
  concurrent `Task`s, each a real `Webhook`+`WebhookDelivery` row, each
  driven through the real `:deliver` action against a real local
  listener; all 50 land `:delivered`, no lost/duplicate delivery.

With this, all 3 pre-existing AshOban resources sharing the fixed
`config/config.exs`/`lib/xaas/application.ex` Oban wiring have now been
directly re-verified this milestone (`HoldRequest`/
`CapabilityLivenessReceipt` last cycle, `WebhookDelivery` this one).
Still honestly open: none of the 3 has had its OWN schedule observed
firing unattended via a live node the way `Xaas.Ultracode.Run`'s `:tick`
was — `HoldRequest` (hourly) and `WebhookDelivery` (real outbound HTTP)
don't fit a bounded, network-safe cycle window;
`CapabilityLivenessReceipt`'s `*/15 * * * *` schedule is the one
remaining candidate that might, left for a future cycle if that specific
evidence becomes valuable.

**No commit this cycle** — no code changed, only verification.

## 2026-09-14 — freeze milestone, production-qualification attempt, push preparation

Re-verified at head `3335ead` before opening a PR:

```
mix format --check-formatted              -> exit 0 (2 pre-existing unformatted
                                              files confirmed not in this branch's diff)
mix compile --force --warnings-as-errors  -> exit 0, 353 files, 0 warnings
MIX_ENV=test mix ecto.migrate             -> "Migrations already up"
mix test --only ultracode                 -> 6 tests, 0 failures (526 excluded)
```

Attempted the narrowest production/release-like qualification available:

```
MIX_ENV=prod mix compile --force --warnings-as-errors
```

Result: a real, pre-existing compile failure unrelated to Ultracode.
`deps/ex4pm`'s bundled Mix task (`ex4pm.engine.gen.adapter.ex`) does
`use Igniter.Mix.Task`, and `:igniter` is scoped out of `MIX_ENV=prod`
compilation — this blocks `MIX_ENV=prod mix compile` for the whole
application today, not for any Ultracode-specific reason.

```
PRODUCTION_LIVE = UNKNOWN
```

Named honestly rather than forced: fixing a repo-wide dependency/env
scoping issue is out of scope for this milestone and does not weaken
the dev-node unattended-epoch proof already closed at `9717626`/`2963835`.

Proceeding to push `feat/ultracode-runtime` and open a PR: the exact
head is green on every check within the milestone's own declared scope
(dev-mode compile/test/format), and `PRODUCTION_LIVE`/multi-node/scale
remain explicitly separate, unproven standings stated in the PR body.

No code changed this cycle.

Claude-Session: https://claude.ai/code/session_01VQ8ro3uJM5qNYFJn265Yc4
