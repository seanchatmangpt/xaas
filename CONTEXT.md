# CONTEXT.md — Ash.Reactor × HDDL × Mermaid Integration Sprint

> Written: 2026-09-09T01:30:41-07:00  
> Conversation: `a2d14a08-faff-4fd5-bc3d-0f1e7f556755`

---

## 1. Mission Statement

This repository (`xaas`) enforces a strict architectural doctrine: **all consequential state mutations must pass through an admitted, transactional, and deterministic control plane** — `Xaas.Actuation.run/4` — rather than ad-hoc, uncoordinated side effects.

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
  ├─ read_one :get_book
  ├─ switch   :circulation_branch  (available? → borrow : hold)
  │     ├─ match branch: transaction :borrow_transaction
  │     │     ├─ create :create_checkout (Checkout)
  │     │     └─ update :decrement_copies (Book)
  │     └─ default branch: create :create_hold (HoldRequest)
  └─ return :circulation_branch
```

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

## 7. Known Issues / In-Progress

### BDD Vitest Integration Test (1/33 failing)

**Test**: `test/bdd` → scenario at line 133 expects `[data-testid="flash-info"]` visible after checkout.

**Root cause (suspected)**: The Playwright-driven BDD test hits the live server. The `checkout_book` handler now calls `Xaas.Actuation.run(Checkout, :borrow, ...)`. In the test environment, either:
- The test seed book has `available_copies: 0`, causing a borrow failure routed to a hold
- The `Actuation.Kernel.admit/2` is raising an error for the test user's authority

**Playwright e2e**: Same scenario failing in `e2e/next-read-ml.spec.cjs:75` — `Next Read Qvest Deck Experience & Dual-Persona Interface › executes student checkout, updates librarian metrics, and displays flash confirmation`

**Not a regression in logic** — the flash path (`put_flash(:info, ...)`) exists and is reachable. The Actuation kernel is correctly returning `{:error, ...}` for the test seed data, triggering the error flash instead.

**Fix needed**: Either ensure test seed books have `available_copies > 0`, or check what the Actuation kernel is returning for the checkout action.

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

## 9. Test Status

| Suite | Status |
|---|---|
| `mix compile --warnings-as-errors` | ✅ 0 warnings (xaas) |
| `mix test recommendation_pipeline_reactor_test.exs` | ✅ 1/1 |
| `mix test actuation_test.exs` | ✅ 4/4 |
| `npx vitest run test/bdd` | ⚠️ 32/33 (1 BDD checkout flash test failing) |
| `npx playwright test e2e/next-read-ml.spec.cjs` | ⚠️ 5/6 (same checkout flash scenario) |

---

## 10. Immediate Next Steps

1. **Fix the BDD/E2E checkout flash failure** — Investigate `Checkout.borrow` action for test seed data; confirm `available_copies > 0` in test fixtures or adjust the test to handle the hold-instead-of-borrow path.

2. **Run full `mix test`** — Verify no regressions across the full Elixir test suite.

3. **`Xaas.Hddl.Mermaid` module** — consider adding `for_domain/1` for `:next_read` key that reads `docs/hddl/next-read.hddl` and generates a diagram from the HDDL domain file directly (currently only supports Reactor module input).

4. **Update `walkthrough.md`** artifact — Document the full Ash.Reactor + HDDL + Mermaid integration for the historical record.

5. **Check `Reactor.Mermaid.to_mermaid` in production mode** — The `for_drawer` call in `toggle_hddl_drawer` uses runtime generation which requires the module to be compiled (works in dev/prod, may be slow). Consider pre-generating all `.mmd` files during `mix assets.deploy`.

---

## 11. Key Technical Learnings

- **`Reactor.Mermaid.to_mermaid/2`** — use `output: :binary` to get a `String.t()`. Returns `{:ok, binary}`. Requires the module to be compiled and loaded.
- **Map step inner scoping** — Steps inside `map :name do ... end` can only `result(...)` from OTHER steps inside the same `map` block. Outer results cannot be referenced inside map inner steps. Fix: collapse map + collect into a single flat `step`.
- **`Decimal` from Ash/Ecto** — `book.grade_level` is returned as `%Decimal{}` not `integer`. Always guard arithmetic with `Decimal.to_integer/1` or pattern match.
- **`input :limit, default: 6`** — Invalid in Ash.Reactor DSL. Inputs don't support defaults.
- **`Reactor.Middleware.event/3`** — Must include a catch-all clause `def event(_event, _step, _context), do: :ok`.
- **`compose` return value** — The composed sub-reactor's `return` step result is what the parent reactor receives as the compose step result.
- **`mix reactor.mermaid`** task — fails with `:nofile` unless beam is pre-compiled. Use `mix run -e '...'` instead.
