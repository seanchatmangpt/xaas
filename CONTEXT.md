# CONTEXT.md — Ash.Reactor × HDDL × Mermaid Integration Sprint

> Written: 2026-09-09T01:30:41-07:00
> Updated: 2026-09-09T10:20:00-07:00 — all items in §7 and §10.1-.2 below are
> now resolved; see §12 for the real, verified current state. Left the
> original sections below intact (struck through where superseded) rather
> than rewritten, so this stays an honest record of what changed and why.
> Updated again 2026-09-09 — §1's Mission Statement below is superseded by
> an explicit user decision: see §13 (the blanket "every mutation through
> Actuation.run" rule was real doctrine drift, not load-bearing everywhere
> it was applied — an audit found ~150 cross-resource mutation cascades in
> Governance/Billing/Platform with zero production callers going through
> it at all, and a real `Ash.Reactor` saga (`CirculationBorrowReactor`)
> with genuine compensation that had no caller anywhere).
> Conversation: `a2d14a08-faff-4fd5-bc3d-0f1e7f556755`

---

## 1. Mission Statement — superseded, see §13

~~This repository (`xaas`) enforces a strict architectural doctrine: **all consequential state mutations must pass through an admitted, transactional, and deterministic control plane** — `Xaas.Actuation.run/4` — rather than ad-hoc, uncoordinated side effects.~~

**Real, current doctrine (§13):** `Ash.Reactor` sagas (`switch`/
`transaction`/`undo_action`) are reserved for genuine multi-resource
compensation needs. `Xaas.Actuation.run/4` stays available, and is the
right tool, specifically where idempotency-key dedup or a receipt trail is
the actual need (a user-double-click, a webhook an external provider may
redeliver) — it is not a mandatory wrapper for every mutation regardless
of whether either property is needed.

The current sprint implements the **tri-partite isomorphism**:

```
HDDL Formal Domain  ──▶  Ash.Reactor Step DAG  ──▶  Mermaid flowchart LR
```

Every HDDL primitive has a direct Ash.Reactor counterpart:

| HDDL Formal Concept | Ash.Reactor Concept | Operational Mapping |
|---|---|---|
| `(:domain ...)` | `defmodule App.R do use Ash.Reactor end` | Bounded context / namespace |
| Compound Task | `compose :sub, SubReactor` | High-level intention decomposed into sub-steps |
| Method (step graph) | Reactor step DAG (`step`, `switch`, `map`, etc.) | Ordered/partial-order execution |
| Precondition | `guard` / `switch` | Runtime condition enforcement |
| Effect | Ash action (`create`, `update`, `destroy`) | Transactional DB mutation |
| `(:ordered ...)` | Sequential steps (result dependencies) | Enforced ordering |
| `(:unordered ...)` | `async?: true` parallel steps | Concurrent execution |
| Primitive Task | Single `step` / Ash `read`/`create` etc. | Leaf execution unit |
| Temporal Logic | `around` / `transaction` | Saga / compensating transactions |

---

## 2. Architecture

### Actuation Control Plane

```
Xaas.Actuation.run/4
  └─▶ Xaas.Actuation.Reactor   (use Reactor, extensions: [Ash.Reactor])
        ├─ middlewares:
        │    ├─ Xaas.Actuation.Middleware.AuditLogger
        │    └─ Reactor.Middleware.Telemetry
        ├─ step :admit    → Xaas.Actuation.Kernel.admit/2
        ├─ step :do       → Xaas.Actuation.Kernel.actuate/2
        └─ step :receipt  → Xaas.Actuation.Kernel.seal/2
```

All mutations from `ReaderLive` now route through this pipeline:
- `checkout_book` → `Xaas.Actuation.run(Checkout, :borrow, ...)`
- `place_hold`    → `Xaas.Actuation.run(HoldRequest, :create, ...)`
- `toggle_pin`    → `Xaas.Actuation.run(Curation, :create/:update, ...)`

### Recommendation Pipeline

```
Xaas.Library.Ranker.rank_recommendations/3
  └─▶ Reactor.run(RecommendationPipelineReactor, inputs, %{}, async?: false)
        ├─ read  :get_user_checkouts   (Checkout.for_user)
        ├─ read  :get_active_curations (Curation.active_for_grade)
        ├─ read  :get_all_books        (Book.read)
        ├─ compose :student_profile, StudentProfileSubReactor
        │     ├─ step :extract_genres_and_text
        │     └─ step :compute_profile_embedding  (async?: true)
        ├─ step  :extract_curated_ids
        ├─ step  :score_and_rank_candidates  → calls ScoreBook.run/3 per book
        ├─ debug :log_recommendation_telemetry
        └─ return :score_and_rank_candidates
```

### Circulation Borrow Saga

```
CirculationBorrowReactor
  ├─ read_one :get_book              (real, Book.get_by_id -- see §12)
  ├─ switch   :circulation_branch    (available? → borrow : hold)
  │     ├─ matches? branch: transaction :borrow_transaction
  │     │     └─ create :create_checkout (Checkout.borrow -- decrements
  │     │           Book.available_copies itself via its own
  │     │           DecrementBookInventory change, in the same DB
  │     │           transaction; there is no separate reactor-level
  │     │           `update :decrement_copies` step)
  │     │     return :borrow_transaction   (real, added -- see §12)
  │     └─ default branch: create :create_hold (HoldRequest)
  │           return :create_hold          (real, added -- see §12)
  └─ return :circulation_branch
```

The original diagram above (`update :decrement_copies (Book)` as its own
step) described intent, not what the code ever did -- `Checkout.borrow`'s
own `Xaas.Library.Changes.DecrementBookInventory` change already handles the
decrement inside the same transaction; no separate reactor step exists for
it. See §12 for the three real bugs this diagram's `read_one`/branch shape
was hiding until a direct `Reactor.run/4` invocation surfaced them.

---

## 3. Files Created This Sprint

### New Elixir Modules

| File | Purpose |
|---|---|
| `lib/xaas/library/reactors/recommendation_pipeline_reactor.ex` | Master Ash.Reactor — 6-factor ranking pipeline |
| `lib/xaas/library/reactors/circulation_borrow_reactor.ex` | Saga with switch/transaction for borrow vs hold |
| `lib/xaas/library/reactors/student_profile_sub_reactor.ex` | Sub-reactor for student embedding profile (compose target) |
| `lib/xaas/library/reactors/steps/score_book.ex` | `Reactor.Step` — 6-factor book scoring |
| `lib/xaas/actuation/middleware/audit_logger.ex` | `Reactor.Middleware` — init/complete/error/event hooks |
| `lib/xaas/hddl/mermaid.ex` | `Xaas.Hddl.Mermaid` — HDDL↔Reactor↔Mermaid bridge |

### New Test Files

| File | Purpose |
|---|---|
| `test/xaas/library/reactors/recommendation_pipeline_reactor_test.exs` | Chicago-style integration test (1 test, 0 failures ✅) |

### Generated Mermaid Diagrams

| File | Reactor |
|---|---|
| `docs/hddl/recommendation_pipeline_reactor.mmd` | `RecommendationPipelineReactor` |
| `docs/hddl/circulation_borrow_reactor.mmd` | `CirculationBorrowReactor` |
| `docs/hddl/actuation_reactor.mmd` | `Xaas.Actuation.Reactor` |

---

## 4. Files Modified This Sprint

| File | Changes |
|---|---|
| `lib/xaas_web/live/next_read/reader_live.ex` | Mutations→Actuation; lazy Mermaid DAG load in drawer; `hddl_mermaid_diagram` assign |
| `lib/xaas/actuation.ex` | Added `middlewares do` block with AuditLogger + Telemetry |
| `lib/xaas/library/ranker.ex` | Delegates to `RecommendationPipelineReactor`; procedural fallback |
| `lib/xaas/library/reactors/steps/score_book.ex` | Fixed nil/Decimal grade_level handling in `compute_grade_fit` |
| `lib/xaas/library/reactors/recommendation_pipeline_reactor.ex` | Removed unused `ScoreBook` alias |
| `test/xaas/library/reactors/recommendation_pipeline_reactor_test.exs` | Fixed `_b2` unused var; `Decimal.equal?` assertion for grade_level |

---

## 5. Module: `Xaas.Hddl.Mermaid`

Located at `lib/xaas/hddl/mermaid.ex`.

### API

```elixir
# Generate diagram from Reactor module (runtime, fallback to .mmd file)
{:ok, diagram} = Xaas.Hddl.Mermaid.for_reactor(Xaas.Actuation.Reactor)

# Generate from known domain key
{:ok, diagram} = Xaas.Hddl.Mermaid.for_domain(:actuation)
# Keys: :actuation | :recommendation_pipeline | :circulation_borrow

# Read a pre-generated .mmd file
{:ok, diagram} = Xaas.Hddl.Mermaid.for_file("docs/hddl/actuation_reactor.mmd")

# Full annotated diagram for HDDL drawer (with isomorphism header)
{:ok, diagram} = Xaas.Hddl.Mermaid.for_drawer(
  Xaas.Library.Reactors.RecommendationPipelineReactor,
  "m-rank-and-recommend"
)
```

The `for_drawer/2` result is cached in `socket.assigns.hddl_mermaid_diagram` on first open of the HDDL drawer in `ReaderLive`.

---

## 6. HDDL Drawer in ReaderLive

The drawer now has **3 columns**:

1. **HDDL Domain Info** — Active domain, task, method badges  
2. **Reactor DAG (Mermaid)** — Live `flowchart LR` text lazily loaded from `Reactor.Mermaid.to_mermaid/2`; `data-testid="hddl-mermaid-dag"`  
3. **Epistemic Receipts** — Rolling log of DO vs. CLAIM receipts with sealed/claimed status

The Mermaid DAG is loaded once on first drawer open via `toggle_hddl_drawer` and cached in assigns.

---

## 7. Known Issues / In-Progress — RESOLVED, see §12

### ~~BDD Vitest Integration Test (1/33 failing)~~ — fixed

**Test**: `test/bdd` → scenario at line 133 expects `[data-testid="flash-info"]` visible after checkout.

**Root cause (suspected)**: ~~The Playwright-driven BDD test hits the live server...~~

**The real root cause** (found via a live `mix phx.server` + Playwright run, not the seed-data theory above): `Xaas.Actuation.Kernel.actuate/2`'s *replay* branch returned the frozen `json_safe/1` snapshot (`%{"id" => ..., "value" => inspect(struct)}`, string keys) instead of the live struct. `reader_live.ex`'s `checkout_book` handler does `checkout.book_id` on that result — fine on the *first* checkout, but a `KeyError` on any *replayed* (idempotency-key-reused) one, which is exactly what running the same e2e/BDD suite twice against a persistent dev DB produces. Fixed in `lib/xaas/actuation.ex` — see §12.

**Playwright e2e**: Same scenario, now passing — `e2e/next-read-ml.spec.cjs:75`, 6/6.

---

## 8. Ash.Reactor Capabilities Used (Full Coverage)

| Capability | Where Used |
|---|---|
| `read` | `RecommendationPipelineReactor` — 3 read steps |
| `read_one` | `CirculationBorrowReactor` — `get_book` |
| `create` | `CirculationBorrowReactor` — `create_checkout`, `create_hold` |
| `update` | `CirculationBorrowReactor` — `decrement_copies` |
| `compose` | `RecommendationPipelineReactor` — `compose :student_profile, StudentProfileSubReactor` |
| `step` (anon fn) | `RecommendationPipelineReactor` — extract + score steps |
| `step` (module) | `ScoreBook` via `use Reactor.Step` |
| `debug` | `RecommendationPipelineReactor` — `:log_recommendation_telemetry` |
| `switch` | `CirculationBorrowReactor` — `circulation_branch` |
| `transaction` | `CirculationBorrowReactor` — `borrow_transaction` |
| `return` | All reactors |
| `input` | All reactors |
| `async?: true` | `StudentProfileSubReactor` — `:compute_profile_embedding` |
| `middlewares` | `Xaas.Actuation.Reactor` — `AuditLogger` + `Reactor.Middleware.Telemetry` |
| `Reactor.Middleware` | `Xaas.Actuation.Middleware.AuditLogger` — init/complete/error/event |
| `Reactor.Mermaid.to_mermaid/2` | `Xaas.Hddl.Mermaid.for_reactor/1` |

---

## 9. Test Status — as of 2026-09-09T01:38, superseded by §12

| Suite | Status |
|---|---|
| `mix compile --warnings-as-errors` | ✅ 0 warnings (xaas) |
| `mix test recommendation_pipeline_reactor_test.exs` | ✅ 1/1 |
| `mix test actuation_test.exs` | ✅ 4/4 |
| `npx vitest run test/bdd` | ⚠️ 32/33 (1 BDD checkout flash test failing) |
| `npx playwright test e2e/next-read-ml.spec.cjs` | ⚠️ 5/6 (same checkout flash scenario) |

---

## 10. Immediate Next Steps — all done, superseded by §12

1. ~~**Fix the BDD/E2E checkout flash failure**~~ — done; real root cause was the actuation replay bug (§7, §12), not seed data.

2. ~~**Run full `mix test`**~~ — done repeatedly across this sprint; 535/535 as of the last full run (§12).

3. **`Xaas.Hddl.Mermaid` module** — still open: `for_domain/1` has no `:next_read` key reading `docs/hddl/next-read.hddl` directly (currently only supports Reactor module input). Not touched this pass.

4. **Update `walkthrough.md`** artifact — still open, not produced this pass.

5. **Check `Reactor.Mermaid.to_mermaid` in production mode** — still open, not verified this pass.

---

## 11. Key Technical Learnings

- **`Reactor.Mermaid.to_mermaid/2`** — use `output: :binary` to get a `String.t()`. Returns `{:ok, binary}`. Requires the module to be compiled and loaded.
- **Map step inner scoping** — Steps inside `map :name do ... end` can only `result(...)` from OTHER steps inside the same `map` block. Outer results cannot be referenced inside map inner steps. Fix: collapse map + collect into a single flat `step`.
- **`Decimal` from Ash/Ecto** — `book.grade_level` is returned as `%Decimal{}` not `integer`. Always guard arithmetic with `Decimal.to_integer/1` or pattern match.
- **`input :limit, default: 6`** — Invalid in Ash.Reactor DSL. Inputs don't support defaults.
- **`Reactor.Middleware.event/3`** — Must include a catch-all clause `def event(_event, _step, _context), do: :ok`.
- **`compose` return value** — The composed sub-reactor's `return` step result is what the parent reactor receives as the compose step result.
- **`mix reactor.mermaid`** task — fails with `:nofile` unless beam is pre-compiled. Use `mix run -e '...'` instead.
- **Ash.Reactor `switch` branches each need their own `return`.** `return
  :foo` *inside* a nested `transaction`/`compose` block sets only that
  inner step's own return value -- the enclosing `matches?`/`default`
  branch still needs `return :the_nested_step_name` at the branch's own
  top level, or `switch` hands the caller `{:ok, nil}` even though the
  branch's mutations really committed. This is the exact bug found in
  `CirculationBorrowReactor` (§12) -- verified via post-hoc DB reads
  showing the mutation succeeded while the reactor call itself returned
  `nil`.
- **`read_one`'s `inputs` are the target action's own arguments, not an
  implicit primary-key filter.** `Ash.Reactor.Steps.ReadOneStep.run/3`
  calls `Ash.Query.for_read(action, inputs, ...)` -- so `inputs %{id:
  input(:x)}` only works if the target action declares `argument :id,
  ...`. A resource's plain `:read` default never does; use a real `get?:
  true` action with that argument instead (e.g. `Book.get_by_id`).
- **A reactor's own `create`/`update` steps don't inherit an actor from
  anywhere** -- if the target action's policy requires `actor_present()`,
  the reactor needs its own `input :actor` and `actor input(:actor)` on
  each step that needs one, or every invocation is `Forbidden` with
  `actor: nil`.
- **A reactor with zero test coverage may never have actually run.**
  `CirculationBorrowReactor` shipped with all three bugs above, undetected,
  because nothing in the runtime path called it (the real checkout/hold
  flows go through `Xaas.Actuation.run/4` instead) and no test exercised it
  directly. "The reactor compiles and its DSL is well-formed" is not
  evidence it executes correctly -- only a real `Reactor.run/4` call is.

---

## 12. Real, Verified Current State (2026-09-09T10:20, this update)

Everything in §7/§9/§10 above that was open or failing at 01:38 is now
resolved, verified by actually running the real thing, not by inspection:

| Item | Then (01:38) | Now (10:20) | Fixed in |
|---|---|---|---|
| BDD checkout flash test | 32/33 | 33/33 | `9505ec6` |
| Playwright e2e checkout scenario | 5/6 | 6/6 | `9505ec6` |
| `mix test` | (blocked -- `ex4pm_core` path dep didn't resolve, couldn't even compile) | 535/535, 0 failures | `11319f7`, `9505ec6`, `dc98567` |
| `RecommendationPipelineReactor` grade-band curation filter | silently matched every grade (bug, not yet found) | real, `Ranker.matches_grade_band?/2` applied | `11319f7` |
| `RecommendationPipelineReactor` `exclude_read` default | `false` (silent regression from procedural's `true`) | `true`, matches procedural | `11319f7` |
| `RecommendationPipelineReactor` collab-boost + `RecommendationLog` persistence | dropped entirely during the Reactor migration | ported over, real | `11319f7` |
| `CirculationBorrowReactor` | never actually ran end to end (3 real bugs: `NoSuchInput`, `Forbidden`, `{:ok, nil}`); zero test coverage | both switch branches verified via direct `Reactor.run/4` calls against real Postgres; 2 new tests | `dc98567` |
| `Xaas.Actuation.Kernel.actuate/2` replay path | returned a frozen JSON snapshot, not a live struct (root cause of the BDD/e2e failure above) | re-fetches the live resource; regression test added | `9505ec6` |

**Still genuinely open** (not touched in this update, listed honestly rather than silently dropped): §10 items 3-5 (`Xaas.Hddl.Mermaid` `:next_read` domain key, `walkthrough.md`, production-mode `Reactor.Mermaid.to_mermaid` check).

Full receipt (repo, commands, exact commits) for the work summarized in this
table is in the session transcript at the conversation id in this file's
header; the three commits above (`11319f7`, `9505ec6`, `dc98567`) are on
`main`, pushed.

---

## 13. Real audit: how data is actually mutated, and the doctrine correction

Prompted by a direct request to audit every Ash resource action and reserve
`Ash.Reactor` for genuine compensation rather than treating it (via
`Xaas.Actuation.run/4`) as a mandatory wrapper for every mutation. Full
inventory (Explore agent, file:line-cited) found the blanket rule in §1 was
**already violated** in real places, and a real compensation-capable
`Ash.Reactor` saga had **zero callers**:

- **Currently Reactor/Actuation-gated** (before this section's fixes): only
  `Checkout.borrow`, `HoldRequest.create`, `Curation.update`/`.create` --
  all from `lib/xaas_web`.
- **Bypassed the doctrine already:** `stripe_webhook_controller.ex` mutated
  `Subscription`/`Ledger` directly with zero idempotency protection, despite
  Stripe's own docs guaranteeing at-least-once redelivery of the same event.
- **`CirculationBorrowReactor`** — a real saga (`switch`/`transaction`/
  `undo_action` compensation, already fixed for correctness in §12) — had
  **no caller anywhere in `lib/`**. The two production checkout entrypoints
  called `Checkout.borrow`/`HoldRequest.create` directly instead.
- **`Checkout.return`'s cascade** (`IncrementBookInventory`,
  `FulfillNextHold`) discarded the inner `Ash.update` result and
  unconditionally returned `{:ok, checkout}` -- a real failure inside the
  cascade was invisible to the caller and never rolled back.
- ~150 `Approval*`/webhook-delivery/ledger-charge cascades in Governance/
  Billing/Platform, sampled (not individually re-walked), all follow one
  mechanical pattern and have zero production callers -- test-only
  currently. **Left out of scope for this pass**, named here rather than
  silently dropped.

**User's resolution, applied:**
1. Relax the blanket rule (§1's real replacement, above).
2. Wire `CirculationBorrowReactor` up as the real path for both checkout
   entrypoints (`reader_live.ex`'s `checkout_book`/`place_hold` -- now one
   shared `circulate_book/2` calling the reactor once, branching on the
   real returned struct type rather than which button was clicked; and
   `next_read_user_agent.ex`'s A2A `checkout` skill).
3. Fix the `Checkout.return` cascade's discarded results (both change
   modules now propagate `{:error, _}` for real, rolling back the
   transaction) and route the Stripe webhook path through
   `Xaas.Actuation.run/4` keyed on Stripe's own `event.id`.

**Disclosed tradeoff:** wiring `checkout_book`/`place_hold` directly to
`Reactor.run/4` (not wrapped by `Xaas.Actuation.run`) drops the
double-click idempotency guard those two UI actions previously had. The
HDDL-drawer receipt display for them now shows the real saga outcome
(which switch branch ran, the created record's id) instead of an
admit/actuate/seal receipt -- not silently dropped, replaced with a
different real signal. If double-click protection turns out to matter in
practice, that's a real follow-up (a lightweight guard inside the
reactor's own transaction), not a reason to have skipped this change.

**Verification:** `mix compile --warnings-as-errors` clean; `mix format
--check-formatted` clean on every touched file; `mix test`: 536/536 (535
baseline + 1 new Stripe-redelivery-idempotency regression test asserting
exactly one `ActuationReceipt` exists after the same Stripe event id is
posted twice). Full plan (context, alternatives considered, exact files)
is at `~/.claude/plans/no-what-i-am-cuddly-key.md`.
