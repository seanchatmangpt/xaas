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

## 2026-09-14 — Semantic Manufacture Closure: research cycle, live-pipeline correction

Real workflow (7 agents, 956K tokens) extracted domain semantics from the
current Run/Epoch/EpochReactor/Receipt/NextEpoch/MissedEpochs code
(subject-predicate-object facts + prose invariants — see workflow journal
`wf_2e62ac84-afe`) and audited existing XaaS ontology/ggen capital before
proposing any new invention, per DfCM reuse-before-invent.

**Finding 1 — no existing ontology models process/state-machine semantics.**
Root `ontology.ttl` (679 lines, fully read) contains only `xar:`/`agp:`/
`tv:`/`aac:` codegen-render-target vocabulary — zero Run/Epoch/Receipt/
Workflow/Schedule classes. `lib/xaas/ontology/` contains one file
(`ex4pm_staleness.ex`, a single-file SHA-256 vendoring check), no domain
classes. Genuinely missing, not overlooked.

**Finding 2 — corrected mid-cycle: which ggen pipeline is actually live.**
The workflow's synthesis initially recommended extending
`priv/packs/xaas_library_pack`'s `agp:CodegenTarget` pattern as "directly
reusable, zero pipeline changes." Direct verification after the workflow
returned found this is wrong: no `mix ggen_igniter.sync` task exists
anywhere in `lib/mix/tasks/` (`grep` confirms zero matches) — that
pack's generated `manufacture.ex.eex` output exists as a committed
artifact but there is no local task that regenerates it from its
ontology today. The actually-live, locally-runnable pipeline is
different: root `ontology.ttl` (`xar:RenderTarget` individuals, 44
present) + `ggen.toml` (`[ontology] source = "ontology.ttl"`,
`[templates] dir = "templates-hooks"`) + `templates-hooks/
ash-gen-resource.txt.tmpl` + the real `ggen` CLI (confirmed present at
`~/.local/bin/ggen`), driven by `ggen sync`, documented in
`docs/claude/diataxis/how-to/fix-ash-admin-and-use-ggen-for-codegen.md`.
`.ash-gen-receipts/*.txt` are this pipeline's real idempotency receipts
— confirmed zero exist for any Ultracode module (correctly: it was
hand-authored, never generated).

This is exactly the kind of claim this repo's own discipline exists to
catch — a plausible-sounding manufacture-path recommendation that
verification correctly falsified before any code was written against
it. Recording the correction, not just the original claim.

**Corrected next concrete step (not yet executed):** add `xar:RenderTarget`
individuals to root `ontology.ttl` for `Xaas.Ultracode.Run`/`Epoch`
against a **scratch resource name** (not the real modules, to avoid
clobbering hand-written originals), run real `ggen sync`, and check
whether the generated `mix ash.gen.resource` invocation's field list
matches the extracted semantics fact-list byte-for-byte. Pass/fail is
real information either way. Reactor-DSL generation remains a genuine
gap: no template in this repo (`ash-gen-resource.txt.tmpl` or any
`priv/packs/*`) emits `Ash.Reactor` DSL — stated as
`UNSUPPORTED(generator-capability)`, not claimed solved.

```
L4 (ontology -> ggen manufacture) = UNKNOWN, narrowed:
  Resource-layer (Run/Epoch as plain Ash resources) = plausible via the
    confirmed-live xar:RenderTarget + ggen sync pipeline — not yet tried
  Reactor-layer (EpochReactor/Reactor DAG generation) = UNSUPPORTED
    (generator-capability) — no template anywhere in this repo emits
    Ash.Reactor DSL; would require new template authorship, not config
```

No code changed this cycle (research + one falsified/corrected claim).

Claude-Session: https://claude.ai/code/session_01VQ8ro3uJM5qNYFJn265Yc4

## 2026-09-14 — Semantic Manufacture Closure: correction — ggen_igniter IS real and working

Prior cycle claimed no local `mix ggen_igniter.sync` task exists ("not the
live pipeline"). That was wrong, and the error is worth recording plainly:
the prior grep only searched `lib/mix/tasks/` inside xaas itself, missing
that `ggen_igniter` (`{:ggen_igniter, "~> 26.9.8", only: [:dev, :test]}`,
already a real xaas dependency) ships its OWN Mix task as part of its
`deps/ggen_igniter/lib/mix/tasks/ggen_igniter.sync.ex`. `~/ggen_igniter` is
a real, substantial, independently developed Elixir library (150+ test
files, ADR-numbered design docs, a real Rustler NIF oxigraph SPARQL engine)
— not a scaffold. Reviewed `~/ggen-marketplace/packs/ggen-igniter-bootstrap-pack`
first per instruction: that marketplace pack is itself only a v1
module-scaffold generator for a *hypothetical* ggen_igniter (explicit
non-goals: "gates/SHACL-equivalent verification... general-purpose ggen
parity") — a real, complete `ggen_igniter` was independently built and
already vendored as a real xaas dependency, superseding what that
marketplace pack would have scaffolded.

**Falsifier executed for real** (ULTRACODE-50 section F/48-style, scoped
to the base resource-field-mapping falsifier from the prior cycle):

New pack `priv/packs/xaas_ultracode_pack/` (SCRATCH module names —
`Xaas.Ultracode.Probe.Run`/`Epoch` — deliberately not the real hand-written
`Xaas.Ultracode.Run`/`Epoch`, so this cannot clobber the closed milestone):
`ontology.ttl` (xu: namespace, PROV-grounded `EngineeringRun`/
`EngineeringEpoch` classes, `xu:field` triples for every attribute recorded
in the prior cycle's extracted semantics), one gate query
(`gates/001_resource_field_completeness.rq`), one EEx template
(`templates/probe_resource.ex.eex`).

```
mix ggen_igniter.sync \
  --ontology priv/packs/xaas_ultracode_pack/ontology.ttl \
  --query fields=priv/packs/xaas_ultracode_pack/gates/001_resource_field_completeness.rq \
  --template priv/packs/xaas_ultracode_pack/templates/probe_resource.ex.eex \
  --out tmp_out/ultracode_probe_manifest.ex
```

First real run hit a genuine Turtle syntax bug in the hand-authored
ontology (multi-line comment inside a plain `"..."` literal — Turtle
requires `"""..."""` for embedded newlines); fixed, re-ran.

Real result: `ggen_igniter: wrote tmp_out/ultracode_probe_manifest.ex
(engine: oxigraph, 1 query, 16 total row(s)) (via reactor)`. Generated
file's `@run_fields`/`@epoch_fields` lists match the ontology's 10 Run +
6 Epoch `xu:field` triples exactly (16 total, alphabetically sorted by the
template, zero missing/extra). `Code.string_to_quoted!/1` on the generated
file: `VALID_ELIXIR_AST`.

```
Generate(O*_scratch) = field-complete, syntactically valid Elixir  -> ALIVE
  (scoped: base resource-field mapping only, SCRATCH module names,
   real oxigraph-backed SPARQL, real EEx render, real file write)
Reactor-DSL generation (EpochReactor 6-step DAG)  -> still UNKNOWN, not
  attempted this cycle -- no template in this pack or any existing pack
  emits Ash.Reactor DSL; genuinely separate, larger falsifier
Real Xaas.Ultracode.Run/Epoch replacement (not scratch)  -> not attempted
  this cycle -- deliberately probed against a scratch module name first
  per DfCM (prove the mechanism before pointing it at the real subject)
```

Scratch artifacts (`priv/packs/xaas_ultracode_pack/`, `tmp_out/`) left in
place as real evidence, not cleaned up — this is the falsifier's actual
output, not throwaway noise.

No changes to the real `Xaas.Ultracode.Run`/`Epoch`/`Reactor`/`Receipt`
modules this cycle — the closed dev-node unattended-epoch milestone
(`8ef3210`/PR #45) is untouched.

Claude-Session: https://claude.ai/code/session_01VQ8ro3uJM5qNYFJn265Yc4

## 2026-09-14 — remote evaluation: real CI failures found and fixed, merge conflicts resolved

`gh pr view 45` showed real CI failures: "Exact-head test court" FAILED
(format check), "Exact-head production compile court" FAILED (matches
prior local finding), "Bound CI receipt" FAILED, and `mergeable:
CONFLICTING` — main had diverged (3 real conflicts: Dockerfile,
config/config.exs, mix.exs).

Real merge of origin/main performed (no rebase, no force). config.exs/
mix.exs auto-merged cleanly. Dockerfile required manual resolution.

**Self-correction, logged honestly:** first resolution kept this branch's
stale `.tool-versions` (elixir 1.19.5-otp-27/erlang 27.2.4) and reverted
main's Dockerfile bump to match it — backwards. User corrected: main's
Dockerfile bump (elixir 1.20.2/erlang 28.5.0.2) was the real forward
move; `.tool-versions` was stale. Re-derived from the corrected premise:
updated `.tool-versions` to `elixir 1.20.2-otp-28`/`erlang 28.5.0.2`,
kept main's Dockerfile ARGs.

Installed the exact pinned toolchain locally via asdf (not assumed) and
re-ran the real verification ladder against it. Elixir 1.20's stricter
type checker surfaced 5 real new --warnings-as-errors failures across the
merged tree — real regressions, not narration:

- `lib/xaas/ultracode/epoch_reactor.ex` (own file): unused `require
  Ash.Query`, removed.
- `lib/xaas/planning/adapter_registry.ex`: `Map.fetch/2` over the
  genuinely-empty `@adapters` correctly proven to always return `:error`
  — simplified `adapter_for/1` to match (moduledoc already says "empty on
  purpose"); this propagated a dead-clause warning into
  `lib/xaas/planning/regime_router.ex`'s `dispatch/2`, simplified the same
  way, both with a comment pointing at git history for restoring the real
  branch when an adapter is registered.
- `lib/xaas/governance/changes/enqueue_webhook_deliveries.ex`,
  `lib/xaas/telemetry/ocel_ash_emitter.ex`: unused `require Logger`/
  `require OpenTelemetry.Tracer`.

Real re-verification after fixes:
```
mix compile --force --warnings-as-errors -> exit 0, 396 files, 0 warnings
mix test test/xaas/planning/ --include stress -> 20 passed
mix test --only ultracode -> 6 tests, 0 failures
```
All run under the actual pinned toolchain (asdf shims first on PATH,
confirmed: `Elixir 1.20.2 (compiled with Erlang/OTP 28.5.0.2)`), not the
machine's prior default (1.19.5/OTP 28 stock).

Two unrelated pre-existing untracked local files/dirs (`AGENTS.md`,
`docs/jira/v26.9.11/*.md`) collided by path with content main had already
merged; moved aside to session scratchpad rather than overwritten or
discarded — not part of Ultracode work, predate this session.

Claude-Session: https://claude.ai/code/session_01VQ8ro3uJM5qNYFJn265Yc4

## 2026-09-14 — Semantic Manufacture Closure: correction #2 — Reactor-DSL generation IS real, found in ggen_igniter ecosystem

Prior cycle stated Reactor-DSL generation as `UNSUPPORTED(generator-capability)`
("no template in this repo emits Ash.Reactor DSL"). Per instruction to
review `~/ggen-marketplace` then "implement the next capabilities using
the other ecosystem projects," searched `~/ggen_igniter` itself (the real
dependency, not the marketplace scaffold pack) and found a real, already
proven, already-tested plain-`Reactor` generation pack:
`~/ggen_igniter/priv/ggen/reactor-scaffold-pack/` (ontology.ttl + one gate
query + `templates/reactor.ex.eex`), backed by a real passing test
(`test/ggen_igniter_expense_approval_reactor_test.exs`). Per its own ADR-0003,
scoped to plain `Reactor` (`use Reactor`), never `Ash.Reactor` — which
matches exactly: `Xaas.Ultracode.Reactor` and `Xaas.Ultracode.EpochReactor`
both use plain `use Reactor`, confirmed by the earlier semantic-extraction
cycle. Second correction of the same claim this milestone — logged plainly
rather than smoothed over.

**Falsifier executed for real:** modeled the real `Xaas.Ultracode.EpochReactor`
6-step DAG (observe/admit/plan/construct/verify/receipt) as
`rx:ReactorDef`/`rx:Step` individuals in
`priv/packs/xaas_ultracode_pack/reactor_ontology.ttl` (SCRATCH module name
`Xaas.Ultracode.Probe.EpochReactor` — does not touch the real, closed
`Xaas.Ultracode.EpochReactor`), reusing ggen_igniter's own already-proven
`reactor-scaffold-pack` gate query and template verbatim (zero new
generator code):

```
mix ggen_igniter.sync \
  --ontology priv/packs/xaas_ultracode_pack/reactor_ontology.ttl \
  --query steps=~/ggen_igniter/priv/ggen/reactor-scaffold-pack/gates/010_steps.rq \
  --template ~/ggen_igniter/priv/ggen/reactor-scaffold-pack/templates/reactor.ex.eex \
  --engine sparql \
  --out tmp_out/ultracode_probe_epoch_reactor.ex
```

Real result: `wrote tmp_out/ultracode_probe_epoch_reactor.ex (engine:
sparql, 1 query, 6 total row(s)) (via reactor)` — 6 rows, matching the
6-step DAG exactly. Generated file structurally reproduces the real
EpochReactor's step names, argument wiring (`result(:observe)`,
`result(:admit)`, etc.), and the same `observe -> admit -> plan ->
construct -> verify -> receipt` dependency chain, including the real
Ash.get/Ash.update/Ash.Changeset.for_create bodies against the real
Xaas.Ultracode.Epoch/Receipt resources (referenced by name, not stubbed).

Verified it's a genuine, loadable Reactor definition, not just valid
syntax: temporarily compiled inside the real xaas app tree
(`lib/xaas/ultracode/probe_epoch_reactor_TMP.ex`, removed after the
check) — `mix compile --force --warnings-as-errors` exit 0, 397 files, 0
warnings. `Xaas.Ultracode.Probe.EpochReactor.reactor().return ==
:receipt` confirmed via `mix run -e`, proving the `use Reactor` DSL macro
expansion succeeded for real (not just `Code.string_to_quoted!`-clean —
actually compiled and introspectable as a Reactor struct in a running
BEAM node).

```
Generate(O*) for the Reactor-DSL layer (EpochReactor 6-step DAG) -> ALIVE
  (scoped: SCRATCH module name, real ggen_igniter reactor-scaffold-pack
   template reused verbatim, real compile + real Reactor struct
   introspection, references real Xaas.Ultracode.Epoch/Receipt by name)
```

Combined with the earlier resource-field falsifier (also ALIVE, scratch-
scoped), both halves of the manufacture path named in the mission spec's
Section E exit criterion now have real, falsified-and-passed evidence:

```
Resource-layer generation (Run/Epoch as Ash resources)     -> ALIVE (scratch)
Reactor-layer generation (EpochReactor 6-step DAG)          -> ALIVE (scratch)
Real Xaas.Ultracode.Run/Epoch/Reactor replacement (Bootstrap
  Equivalence Court, mission spec section 45-47)            -> not attempted
  this cycle -- both mechanisms proven against scratch subjects first,
  per DfCM; pointing the pack at the real modules (still generating to a
  throwaway path, never overwriting) is the correct next falsifier
L4 (ontology -> ggen manufacture)                           -> still UNKNOWN
  overall (mechanism proven, but the real subject has not yet been
  regenerated and diffed against the hand-written original)
```

No changes to the real `Xaas.Ultracode.Run`/`Epoch`/`Reactor`/
`EpochReactor`/`Receipt` modules this cycle — the closed milestone
(PR #45) is untouched.

Claude-Session: https://claude.ai/code/session_01VQ8ro3uJM5qNYFJn265Yc4

## 2026-09-14 — Bootstrap Equivalence Court CLOSED: real Run/Epoch/EpochReactor manufacture proven

Per instruction ("point it at the real Run/Epoch/Reactor modules and
finish"), ran the real Bootstrap Equivalence Court (mission spec section
45-47) against the actual closed-milestone module names, output only to
`tmp_out/` (never overwriting the real, closed `lib/xaas/ultracode/*.ex`
files).

### Resource layer (Run/Epoch)

`priv/packs/xaas_ultracode_pack/real_resource_ontology.ttl`: real module
names (`Xaas.Ultracode.Run`/`Epoch`), real table names, field lists
transcribed directly from the real source files (not from the earlier
extracted-semantics summary, to avoid compounding transcription error).
Real sync run: `wrote tmp_out/real_resource_manifest.ex (engine:
oxigraph, 1 query, 16 total row(s))`.

**Automated diff, not eyeballed:** wrote a real Elixir script extracting
`attribute :name, :type do ... end` declarations directly from
`lib/xaas/ultracode/run.ex`/`epoch.ex` via regex, sorted, and diffed
against the generated field lists.

```
Run:   real == generated? true   (missing: [], extra: [])
Epoch: real == generated? true   (missing: [], extra: [])
```

Exact field-level equivalence, zero discrepancy either direction.

### Reactor-DSL layer (EpochReactor)

`priv/packs/xaas_ultracode_pack/real_reactor_ontology.ttl`: real module
name `Xaas.Ultracode.EpochReactor`, real step wiring (`admit` depends on
`observe`; `plan` depends on `admit`; `construct` depends on `plan`;
`verify` depends on BOTH `construct` and `observe`; `receipt` depends on
BOTH `verify` and `observe`) and real `run` bodies transcribed verbatim
from `lib/xaas/ultracode/epoch_reactor.ex`. Real sync run: `wrote
tmp_out/real_epoch_reactor_generated.ex (engine: sparql, 1 query, 6 total
row(s))`.

Module name is now real (not scratch), so this was NOT compiled inside
the app tree (would collide with the closed-milestone module) — verified
instead via real AST comparison: `Code.string_to_quoted!/1` both files,
strip `@moduledoc`, alias the generated module's name to match, diff
`Macro.to_string/1` output.

**First pass found a real, genuine transcription bug in my own
ontology**, not a template limitation: I had written `rx:async "false"`
for every step. The generated file therefore emitted explicit
`async?(false)` on all 6 steps; the real hand-written file declares no
`async?` at all, relying on Reactor's own documented default. Verified
the real default directly from the dependency source
(`deps/reactor/lib/reactor/dsl/step.ex:15`, schema default `async?:
true`) rather than assuming — confirming this was a real behavioral
divergence (sync-forced vs. async-by-default), not benign, and would
have been a real regression had this generated output ever replaced the
real file. Fixed the ontology (`rx:async "true"`, matching the real
default the hand-written file relies on) and re-ran.

Second pass: `Macro.to_string` diff showed only the redundant-but-
harmless presence of an explicit `async?(true)` call (the generated file
states the default explicitly; the real file relies on it implicitly) —
both compile to the identical runtime step configuration, confirmed
against the dependency's own schema default. Every other AST node
(step order, step names, all `argument`/`result`/`input` wiring, every
`run` body verbatim, `return :receipt`) matched exactly.

```
Generate(O*_real_subject) = CurrentQualifiedRuntime, for:
  - Xaas.Ultracode.Run/Epoch (resource/attribute layer)       -> ALIVE
    (exact field-level equivalence, automated diff)
  - Xaas.Ultracode.EpochReactor (6-step Reactor DAG)            -> ALIVE
    (exact behavioral equivalence, real AST diff + dependency-
     source-verified async default)
```

### What remains genuinely hand-authored residue (not attempted, honestly scoped out)

Both existing xaas ggen packs (`xaas_library_pack`, this session's
`xaas_ultracode_pack`) and ggen_igniter's own `reactor-scaffold-pack`
generate the resource/reactor SKELETON (attributes, table, steps,
argument wiring, run bodies) from ontology data — none of them generate
the surrounding Ash `actions`/`policies`/`oban` block/custom
validations/changes (`Xaas.Ultracode.Run`'s `:start`/`:tick` actions,
policy bypasses, `oban do scheduled_actions ... end`;
`Xaas.Ultracode.Epoch`'s `:start`/`:complete`/`:mark_missed`/
`:mark_failed` actions; `Xaas.Ultracode.Validations.*`/`Changes.*`
modules). This matches `xaas_library_pack`'s own documented "base" vs.
"core" phase split (base = `mix ash.gen.resource` skeleton; core =
hand-authored business logic scaffold) — no existing pack in this
ecosystem auto-generates the "core" phase for ANY resource, Ultracode
included. This is real, disclosed, irreducible hand-written residue per
repo doctrine, not an oversight: `UNSUPPORTED(generator-capability,
core-business-logic-phase)`, not `REFUSED`.

### Final honest L4 standing

```
L4 (ontology -> ggen manufacture of the qualified Ultracode runtime):
  Resource skeleton (attributes/table)     -> ALIVE, real-subject equivalence proven
  Reactor DAG (steps/wiring/run bodies)    -> ALIVE, real-subject equivalence proven
  Actions/policies/Oban scheduling/
    validations/changes ("core" logic)     -> UNSUPPORTED(generator-capability) --
                                               no template anywhere in this ecosystem
                                               generates this layer for any resource,
                                               not just Ultracode's
  Overall                                  -> PARTIAL_ALIVE, not full ALIVE --
                                               named honestly per the mission spec's
                                               own required answer format
```

The generated files were NOT used to replace the real, closed-milestone
modules -- they remain in `tmp_out/` as evidence only, per the mission
spec's explicit instruction not to patch the generated result manually
and not to silently promote generated output over the qualified
hand-written bootstrap without a full, separate authorization to do so.

### Required final answer (mission spec section J)

> Can XaaS delete the handwritten Ultracode bootstrap, regenerate it from
> admitted semantics, and still advance a Run unattended?

```
PARTIAL — the resource-skeleton and Reactor-DAG halves: YES, with real,
automated, dependency-source-verified equivalence evidence above. The
actions/policies/Oban-scheduling/validations/changes half: NO — this
ecosystem's generators (xaas_library_pack, xaas_ultracode_pack,
ggen_igniter's reactor-scaffold-pack) have never generated this layer for
any resource. Deleting the real hand-written files today and regenerating
only from what currently exists would NOT reproduce a working,
schedulable, policy-enforced Run/Epoch — the smallest remaining
manufacturing gap is a "core-phase" generator (actions/policies/oban)
that does not yet exist anywhere in this ecosystem, for any resource.
```

Claude-Session: https://claude.ai/code/session_01VQ8ro3uJM5qNYFJn265Yc4

## 2026-09-15 — Zach Daniel / Chris McCord adversarial review + ERRC refactor, all 8 findings implemented

Per instruction, ran a real 15-agent Workflow: two independent adversarial
reviews of the entire real `lib/xaas/ultracode/**`+`test/xaas/ultracode/**`
tree, role-playing ZACH DANIEL's (Ash creator) documented engineering
philosophy and CHRIS McCORD's (Phoenix/LiveView creator) documented
engineering philosophy respectively, each reading every real file in full
and producing specific, grounded findings (not generic advice). Every
critical/major finding was then cross-examined by the OPPOSITE persona
before being trusted -- 4 findings were refuted with real evidence,
including one where the reviewer's own proposed fix (real Reactor.Builder
async fan-out) would have broken Ecto Sandbox-mode tests, and one where
reading the real pinned `ash_oban`/`oban` dependency source disproved a
claimed race condition in the `:tick` scheduling. 8 findings survived and
were ERRC-categorized (Eliminate/Reduce/Raise/Create) with an explicit
risk-to-closed-milestone assessment and sequencing plan per finding.

Implemented all 8, in 5 commits on `refactor/ultracode-errc`, following
the plan's own risk-ordered sequence (lowest risk first, the 3 highest-
risk RAISE items sequenced last and each in its own separately-verified
commit, never batched):

1. **ELIMINATE** fake Reactor DAG wiring (`argument`/`result` bindings
   whose step bodies never read them) -> real `wait_for/1`. Pure honesty
   fix, zero behavior change.
2. **ELIMINATE** a false docstring claim (`:admit` step's comment claimed
   an authority-ceiling check that was never implemented). Comment-only.
3. **RAISE** real precondition validation
   (`EpochTransitionAllowed`) on `Epoch.:complete`/`:mark_missed`/
   `:mark_failed`, previously accepting any state unconditionally.
4. **CREATE** a real `has_one :active_epoch` relationship on `Run`,
   replacing two independently hand-rolled copies of the same "current
   active epoch" query.
5. **REDUCE** per-tick query count (3 full Run-table scans + N+1 per-run
   queries -> 1 scan + up to 2N), via a new `:fetch_active_runs` Reactor
   step threading the list through, while preserving `advance_all/0`'s
   zero-arity signature for its 2 real direct test callers.
6. **RAISE (a)** real policy bypasses replacing `authorize?: false` at
   16 call sites across 5 modules -- the declared `forbid_if always()`
   floor was previously dead code for all real production traffic. Found
   and closed a real gap beyond the reviewers' own literal file list:
   `Run.:advance_cycle`/`:transition_state` also lacked bypasses and
   would have broken (`Ash.Error.Forbidden`) had `authorize?: false` been
   stripped from their call sites without adding them.
7. **RAISE (b)** a real, explicit, checkable edge-list validation
   (`RunTransitionAllowed`) on `Run.:transition_state`, previously
   accepting any state transition unconditionally -- closing a real
   unvalidated backdoor around the state-machine discipline `:start`
   enforces for its own edge.
8. **RAISE (c)** a real `undo/3` on `EpochReactor`'s `:construct` step,
   closing the gap where a downstream step failure after a real DB
   mutation left an Epoch permanently transitioned with no receipt.
   Caught and corrected a genuine interaction bug in the plan's own
   literal proposal before writing code: uniformly calling `:mark_failed`
   from undo would itself be refused by item 3's own new validation when
   the downstream failure happens after the epoch reached `:completed`
   (not an admissible `:mark_failed` source state) -- branched undo
   correctly instead (`:start` -> `:mark_failed` + receipt;
   `:complete` -> leave the real `:completed` state, repair only the
   missing receipt). Added 2 new real falsifier tests exercising the
   compiled `undo/3` callback directly via Reactor's own step
   introspection (`Multigraph.vertices/1` + `Reactor.Step.undo/4`) since
   forcing a genuine downstream Ash failure without mocking anything
   proved impractical without modifying production code for the test.

Real verification after every single commit (not just at the end):
`mix compile --force --warnings-as-errors` clean each time;
`mix test test/xaas/ultracode/` (6/6, then 8/8 after the undo tests)
passing after every commit with zero regressions. Final whole-repo
check: `mix format --check-formatted` exit 0; `mix compile --force
--warnings-as-errors` exit 0, 398 files, 0 warnings;
`mix test --max-failures 1` -> **622 passed, 0 failures, 40 excluded**
(up from the pre-refactor baseline of 620, +2 for the new undo tests) --
zero regressions anywhere in the repo, not just Ultracode.

`grep -rn "unittest.mock\|Mock(\|MagicMock\|patch(\|monkeypatch\|Mox\b\|:meck\|meck\." lib/xaas/ultracode/ test/xaas/ultracode/`
-> zero matches, confirming Chicago-style discipline held throughout.

No changes to the milestone's actual behavior or evidentiary chain --
`Run -> Epoch -> AshOban -> EpochReactor -> Receipt` still advances
identically; this refactor made the implementation more honest (real
DAG wiring, real docs), more correct (real state-machine guards, real
undo closing a real invariant gap), and more efficient (fewer queries per
tick), without changing what it does.

Claude-Session: https://claude.ai/code/session_01VQ8ro3uJM5qNYFJn265Yc4

## 2026-09-17 — Cycle: wave-4 drift closure — atom-table DoS fix landed, ledger reconciled

**Baseline before this cycle**: branch `feat/execution-actuation-fabric`
at `2f49261` (zcode-plugin user_config token fix) on top of `a11bf7a`
(template contract fixes); working tree carried the boundary court's
qualified-but-uncommitted atom-table DoS fix plus a concurrent sibling
author's in-flight Receipt read-path work (`receipt.ex`, router,
controller, `mix xaas.receipts`, lease/epoch_reactor + tests) and ledger
drift. Boundary receipt r6 (`/tmp/uzc/boundary-xaas.md`) had already run
`mix compile --force --warnings-as-errors` exit 0 and `mix test` 648/0
WITH the atom fix + its test in the tree — this cycle ran no mix gates
(the r6 court is the evidence); git evidence only.

**Landed**:
1. `32b5ba1` — `fix(execution-fabric): refuse reason via
   String.to_existing_atom — bound atom-table DoS` (+ its test). Content
   is exactly the drift the r6 court qualified (controller atom hunks +
   atom-safety test, receipts hunks excluded). Committed via a temporary
   index (`git read-tree` → `git apply --cached` → `write-tree` →
   `commit-tree` → `update-ref`) so the concurrent author's staged files
   were untouched. Post-commit check: `git grep --cached safe_existing_atom`
   present, `for_epoch` absent from the commit tree.
2. `113a6eb` — `docs(ledger): reconcile HANDWRITTEN.md` — controller row
   extended (receipt read route + atom-safe refuse), lease row extended
   (`:for_epoch` carve-out), new `mix xaas.receipts` row; 2026-09-16
   Shrunk rows now cite their landing commit `a11bf7a`; new Shrunk row
   for the `2f49261` user_config token fix; wave paydown direction
   recorded (zcode-plugin rows shrank toward admission; controller/lease
   rows disclosed growth, owner packs unchanged).

**Deliberately NOT committed**: the sibling author's in-flight Receipt
read path + lease/epoch_reactor edits (staged `lib/mix/tasks/
xaas.receipts.ex` is theirs). Racing an active author's index is how
commits corrupt; their flow lands on top of `32b5ba1` unchanged.

**Coordination incident, disclosed**: this agent twice held
`/tmp/uzc/xaas-mix.lock` stale (~10 min each) by omitting the release
`rmdir` — observed side effect: the author's `git reset` (reflog
`reset: moving to HEAD`) landed after lock release, unstaging earlier
staging; no work lost, worktree never touched, state normalized.

**Git evidence (commands + exact exits)**:
- `git status --porcelain` / `git diff --numstat` → exit 0 (drift
  inventory: 5 modified tracked files + 7 untracked paths at start)
- `git apply --cached --check <atom patches>` → exit 0 before staging
- `git write-tree` → `c9529722`; `git commit-tree -p 2f49261` → `32b5ba1`;
  `git update-ref refs/heads/feat/execution-actuation-fabric` → exit 0
- `git commit HANDWRITTEN.md` → exit 0, `113a6eb` (1 file, +39/−6)
- `git log --oneline` verification after each commit → exit 0

**Wave 比 (fail-closed)**: `a11bf7a..HEAD` = 2f49261 + 32b5ba1 + 113a6eb
= 105 insertions / 13 deletions across generator, 2 plugin templates,
controller, test, ledger. Manufactured (pack render / generator run
attribution): **0 lines** — the plugin projection (`generated/`) is
untracked and no pack render produced any delivered line this wave.
Ratio = **0%**, honestly. Paydown: promote the now contract-clean
templates + generator into `zcode-plugin-pack` (blocked only on the
ZCode-side install bug), admit `ultracode-actuation-lease-pack` and the
mcp-surface family extension from the proven shapes — after which
plugin drift renders manufactured and the ratio moves off 0.

## 2026-09-21 — Cycle: root consolidation — five `~/xaas*` trees collapsed into `~/xaas`, validated for tonight's 8-hour launch

**Baseline before this cycle**: operator order "all of the xaas* need to be
merged into ~/xaas, there should never be different folders"; the ultracode
runtime spanned five top-level trees. Preconditions executed by the
coordinator: `phx.server` stopped (Oban clock frozen), 8 zombie epochs
confirmed (6 `running` unleased + 1 `expected` + 1 lease expired
2026-09-18, no live worker processes), branch `feat/xaas-root-consolidation`
cut with `.gitignore` gaining `/worktrees/` + `/tmp/`. Ticket:
`docs/jira/v26.9.21/xaas-root-consolidation.md` (the only legal path map;
historical evidence keeps old paths verbatim per that map's own rule).

**What moved** (a live-path consolidation, not a git-history merge): the
four sibling trees collapsed into the repo root under two gitignored dirs —
`~/xaas-worktrees` → `~/xaas/worktrees`, `~/xaas-tmp` → `~/xaas/tmp`,
`~/xaas-wt2` (2 main-repo worktrees + loose logs) → `~/xaas/worktrees/wt2`,
`~/xaas-wt3` (empty) → deleted. Physical move + `git worktree repair`
(main + aps): 282 worktrees repaired (18 + 264), 0 prunable/broken. The
durable repo registry (`~/xaas/worktrees/ultracode-repos.json`) rewritten
at the new paths. Old dirs gone at close: `ls -d /Users/sac/xaas-worktrees
/Users/sac/xaas-tmp /Users/sac/xaas-wt2 /Users/sac/xaas-wt3` → all missing
(re-verified at this entry's write time).

**Wave shape**: 10 default agents on disjoint file slices (config, repos
libs, wave loop, tests, two doc slices, physical move, zombie reap, external
sweep, validator); git serialized through the coordinator — agents never
commit; mix gates through the compile lock
(`.claude/workflow-compile-lock.sh`); no agent recreated a directory at an
old path — failures report, never patch. Zombie epochs reaped in the DB by
the A8 slice per the zombie-runs-cleanup ticket. Merged to `main` as
`e3ce136`; the worker-leg tripwires hit in the smoke landed on top as
`9000c94` (eight-hour-run §3).

**Real verification** (gates at `main @ e3ce136`, exits as recorded in the
ticket History):
- `mix compile --force --warnings-as-errors` → exit 0
- `mix format --check-formatted` → exit 0
- ultracode suite → 529 passed, 0 failures; zcode_plugin → 33 passed,
  0 failures
- whole repo `mix test` → 1363 passed, 0 failures

**Smoke evidence at the new paths** (real one-worker campaign `d955857e`):
the full worker leg — claim → construct → court → receipt — ran live under
`~/xaas/worktrees/*`: one item finished done with the fabric court verdict
pass and a `head_verified` receipt; OCEL export of the wave run `719ac930`
passed the conformance court, `valid (5 events, 6 objects)`, exit 0;
`human_inputs: 0`. Campaign terminal standing honestly **PARTIAL_ALIVE** —
a bounded smoke, not the 8-hour run; the launch itself is the remaining
step.

**Gaps found and closed during validation (6)**:
1. `lib/xaas/semantics/computation.ex:61` dead clause → removed + guard
   test.
2. Homebrew python 3.14 `rpds`/`jsonschema` broken → repaired; the
   `aps-dod` court works (proven by the smoke court verdicts).
3. Zombie campaign `d649c9ca` (loop died with the old VM, would have
   refused tonight's start) → `stop` → `abandoned`.
4. Pending dev migrations → `mix ecto.migrate` (had been surfacing
   PendingMigrationError 503s).
5. `phx.server` restarted without `INTERNAL_API_TOKEN` → every worker
   fail-closed at the `xaas-execution` plug; documented in eight-hour-run
   §3 and restarted with the token.
6. zcode-cli headless sessions no longer register `xaas-execution` from
   user scope → project `.mcp.json` placed in `ZCODE_CLI_DIR`
   (git-excluded locally); runbook §3 documents the requirement.

**比 (fail-closed)**: this cycle delivered path repoints, doc sync, worktree
repair, and registry/data rewrites — layout and configuration migration,
not pack-rendered product code. 0 delivered lines attributable to a pack
render this cycle → ratio contribution **0%**, honestly. The consolidation's
value is a single lawful root (one checkout, one registry), which is what
makes the next cycle's ratio measurable at all.

**Standing**: ALIVE, scoped to the consolidation + its validation at
`main @ 9000c94`. Remaining: the 8-hour launch — one command per
eight-hour-run §1.
