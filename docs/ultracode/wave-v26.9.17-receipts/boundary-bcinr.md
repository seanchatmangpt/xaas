# Receipt — qualify-boundary(bcinr, cap-bounded-select)

Wave: SA2A release v26.9.17 qualification, agent 3/10. Executed 2026-09-17.
Subject: /Users/sac/bcinr — pinned head `f70999c0159fbdbecc1f2e9d2102d57ef71e7607`, branch `release/26.9.15`.
Drift check: `git rev-parse HEAD` → `f70999c0159fbdbecc1f2e9d2102d57ef71e7607` — EXACT match, tree clean (`git status --porcelain` empty). No drift.

**Classification (FOND oneof): `qualified`.**

## r3 semantics under test

`bcinr = SELECT`: bounded selection of alternatives with explicit bounds
(depth/paths/combinations/cost/wall-time/risk), never enumerating the product.

## 1. Court discovery

Stack: Rust nightly workspace (`rust-toolchain.toml` pins `nightly` minimal + rustfmt/clippy; local cargo/rustc 1.99.0-nightly — matches pinned channel).
Court = repo's own CI, `.github/workflows/ci.yml`:
- PR gate: `cargo clippy --workspace --all-targets --all-features -- -D warnings` + targeted per-crate suites
- Push rail: `cargo test --workspace --all-targets --no-fail-fast` ← gate executed
Cheapest high-information gate chosen: the workspace test court (clippy subsumes `cargo check` per CI's own comment; full test rail exercises the capability tests directly).

## 2. Court run — exact commands + exit codes

| Command | Exit | Result |
|---|---|---|
| `git rev-parse HEAD` | 0 | `f70999c0159fbdbecc1f2e9d2102d57ef71e7607` (matches pin) |
| `git status --porcelain` | 0 | empty (clean) |
| `cargo test --workspace --all-targets --no-fail-fast` | **0** | all workspace targets green (cold build ~full workspace, `--no-fail-fast`, zero failures) |
| `cargo test -p bcinr-mfw-ir --lib epoch` | 0 | 3 passed / 0 failed (`descend_refuses_past_budget`, `zero_budget_refuses_immediately`, `descend_increments_up_to_budget`) |
| `cargo test -p bcinr-pddl --lib powl_bridge` | 0 | 3 passed / 0 failed incl. `a_plan_past_the_step_cap_is_refused_not_panicked_or_silently_truncated` |
| `cargo test -p bcinr-pddl --lib search` | 0 | 10 passed / 0 failed incl. `exact_rail_is_never_starved_beyond_max_gap`, `portfolio_solve_reports_exhausted_with_no_candidates_for_infeasible_problem` |

`inspection ≠ execution`: the three capability suites above were EXECUTED this session with observed `ok` lines and exit 0, against the exact pinned subject.

## 3. Capability evidence — owns predicate: IMPLEMENTED, not merely named

### Explicit bounds (typed dimensions)
- `crates/bcinr-mfw-ir/src/outcome.rs:120-127` — `enum BoundKind { PlanDepth, GroundActions, FrontierStates, SearchSteps, RecursiveDescent, PartitionBoxes }`: depth, paths/actions, frontier states, cost (search steps), recursion, partition combinations. Six explicit bounds; no ambient unbounded search.
- `crates/bcinr-mfw-ir/src/outcome.rs:132-136` — `struct BoundHit { kind, limit: u64, observed: u64 }` — every truncation carries limit AND observed value: truncation-as-evidence by type.
- `crates/bcinr-mfw-ir/src/epoch.rs:16-22` — `struct EpochBounds { max_ground_actions, max_plan_depth, max_search_steps, max_partition_boxes }`; doc: "Every field corresponds one-to-one with a `BoundKind` variant."

### Enforcement on real paths
- `crates/bcinr-mfw-ir/src/epoch.rs:41-53` — `DescentMeter::descend()` returns `Err(BoundHit { kind: RecursiveDescent, limit, observed })` when depth would exceed budget; refused attempt does not corrupt depth.
- `crates/bcinr-pddl/src/ground_v2.rs:407-408` — `Err(ExactClassicalError::SearchStateBoundExceeded { limit })` when `visited.len() > max_states`; `:433` — `PlanDepthBoundExceeded { limit: max_depth }`.
- `crates/bcinr-pddl/src/search.rs:394-403` — `MfwPortfolio::solve()` loops `for _ in 0..self.max_ticks`; on timeout returns `TickBudgetExhausted(candidates)` — candidates carried as evidence, doc (:333-340): "never presented as verified, only as what was found before the exact rail settled the question."

### Public surface (reachability — the "not just named" proof)
- `crates/bcinr-pddl/src/mfw/planner.rs:317` — `pub fn plan(domain_text, problem_text, profile)`: threads `self.bounds` into the grounded epoch, then `MfwPortfolio::new(exact, exploit, self.max_gap, self.max_ticks)` (bounded selection over alternative rails: exact BFS + q-lens exploit), and maps every bounded outcome to a typed error: `PortfolioBounded(BoundHit)`, `PortfolioTickBudgetExhausted`, `PortfolioExhausted(ExhaustionWitness)`. No silent path.

### No vacuous / silent truncation
- `crates/bcinr-powl/src/wf_to_powl.rs:163` — `DEFAULT_DEPTH_BUDGET: usize = 64`.
- `crates/bcinr-powl/src/wf_to_powl.rs:191-237` — `convert_and_verify(net, budget, max_len)`: `max_len == 0` → `RefusalReason::VacuousLanguageBound` (a zero bound is refused, never silently accepted); disagreement at the checked bound → `BoundedLanguageAgreementFailed { checked_len }`; doc states precisely what the truncated comparison does NOT establish.
- `crates/bcinr-guarded/src/taxonomy.rs:244-260` — `BudgetExhausted` ("The bounded recursion budget ran out before termination."), `SoundnessUndecided` ("reachability graph exceeded MAX_REACHABLE_MARKINGS ... Undecided, not decided favourably") — undecided ≠ decided-favourable, encoded in the type.

### One test that proves a bound is enforced (execution receipt this session)
`crates/bcinr-pddl/src/powl_bridge.rs:171` — `a_plan_past_the_step_cap_is_refused_not_panicked_or_silently_truncated`: a plan of `MAX_POWL_TAPE_STEPS + 1` steps must return `Err(Pddl8Error::BoundExceeded { limit, got })` with `limit == MAX_POWL_TAPE_STEPS`, `got == MAX_POWL_TAPE_STEPS + 1` — asserted exactly; `... ok` observed, exit 0. Companion `a_plan_at_exactly_the_step_cap_still_lowers_successfully` proves the bound is exact (permitted at the boundary, refused one past).

## 4. Classification

`qualified` — build alive, capability implemented and enforced with typed evidence, proving tests executed green this session.

## 5. Repairs / alternates

None required. No branch created (`fix/bcinr-v26.9.17-boundary` unused). No push/PR/merge performed. Zero bytes written to the repo (probe was read-only; court writes confined to `target/`).

## Falsifiers attempted

1. "Named but not implemented" — FALSIFIED: bounds constructed and consumed in `pub fn plan` (`mfw/planner.rs:317+`), enforced on grounding, search, and portfolio paths with typed refusals.
2. "Silent pruning somewhere" — FALSIFIED: every truncation path found emits a typed witness (`BoundHit{limit,observed}`, `BoundExceeded{limit,got}`, `VacuousLanguageBound`, `BoundedLanguageAgreementFailed`, `SoundnessUndecided`, `TickBudgetExhausted`, `BudgetExhausted`).
3. "Vacuous bound accepted" — FALSIFIED: zero budget / zero max_len refused (`zero_budget_refuses_immediately ... ok`, `VacuousLanguageBound`).
4. "Bound is approximate/off-by-one" — FALSIFIED: boundary-exact tests (`at_exactly_the_step_cap` passes, `past_the_step_cap` refused, `descend_increments_up_to_budget` permits exactly budget, `exact_rail_is_never_starved_beyond_max_gap` enforces fairness gap).

## Standing

**ALIVE** — observed execution against the exact pinned subject (`f70999c0`) with the repo's own court (workspace test rail, exit 0) plus three targeted capability suites (exit 0 each), in this session.

## What the operator did NOT have to write

Everything in this qualification: court discovery, execution, capability verification, receipts. Zero repair bytes were needed (zero bytes hand-written on 産面; the repo required no change). Operator keystrokes this task: none beyond dispatch.
