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
