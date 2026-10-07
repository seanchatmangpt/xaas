# W984ct — Lane Receipt: Quiescent-Stop Concurrency Contract (W984cf-1/-2 fixes)

- **Subject**: branch `feat/playwright-surface`, working tree (uncommitted, per lane law — coordinator commits)
- **Scope**: minimal `lib/` fix for W984cf's two concurrency findings + flipped pins in the W984cf court
- **Standing**: ALIVE (compile clean; target courts 19/19 ×2 seeds + 5/5 ×3 more seeds; 3 failures in `run_idempotency_deepening_test.exs` confirmed pre-existing by A/B with HEAD's file)
- **Files written** (only these three):
  - `lib/xaas/actuation/quiescent_stop.ex` (fix)
  - `test/xaas/oversight/w984cf_oversight_depth_test.exs` (two finding pins flipped, docstring updated)
  - this receipt

## Per-finding fix

### W984cf-1 — unhandled kernel replay envelope (CaseClauseError crash)

`do_stop/2` (now `run_stop/2`) gained the missing kernel-envelope clause:

```elixir
{:ok, %{status: :replayed}} ->
  {:ok, %{already_stopped: true}}
```

The kernel's replay envelope (`actuation.ex:55-63`, `seal` at `actuation.ex:446-455`) means the
identical stop DO already sealed for that exact key — the honest loser outcome is the idempotent
replay `{:ok, %{already_stopped: true}}`: no new DO, no crash. The envelope contract in `do_stop/2`
is now total over the kernel's `:succeeded` / `:replayed` / `:refused` / `:failed` statuses.

### W984cf-2 — fresh-key TOCTOU on the `stopped?` attractor (both racers win the DO)

Fresh keys are now routed through intent-ledger uniqueness — the kernel's own exactly-once
primitive — via a subject-scoped claim intent `quiescent-stop:<resource>:<subject_id>` before the
DO. The claim row is a genuine stop intent (same resource/action/subject/input, real projection
identity from `Xaas.Semantics.Registry.admit/1`+`hash/1` through the resource's own `:admit`
action and its validations). Arbitration:

- exactly one racer's claim insert commits → it runs the stop DO;
- the loser's insert fails on `unique_idempotency_key` → takeover of a dead claim
  (`:failed`/`:refused` → re-`:admitted`), otherwise bounded wait (40×25 ms) on the attractor:
  quiescent → typed `:REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT`; window expires → typed
  `:REFUSED_STOP_CLAIM_CONTENTION` (new typed atom, moduledoc contract row added);
- a claim left `:failed` by a failed stop DO is marked via `release_claim/2` so the next stop's
  takeover leg can proceed (a failed stop cannot strand the subject).

One caveat, disclosed: the kernel's own `:replayed` envelope leg in `run_stop/2` becomes
defensive-only under claim arbitration (the loser is refused at the claim, never reaching the
kernel) — it is kept as envelope totality and pinned by the same-key court's typed-loser
assertion; the sequential same-key replay (`{:ok, %{already_stopped: true}}`) remains the
pre-existing pre-DO `find_intent` path.

## Pin flips (test/xaas/oversight/w984cf_oversight_depth_test.exs)

- **Same-key race test**: was `length(receipts) == 1` + `crashes == [] or [CaseClauseError]`.
  Now: exactly one receipt, every loser outcome typed (`{:ok, %{already_stopped: true}}` or a
  `:REFUSED_STOP_*`/`{:refused,_}`/`{:failed,_}` via `typed_stop_refusal?/1`), `crashes == []`
  (the CaseClauseError allowance is deleted).
  Mutation rationale: deleting the `:replayed` clause or the claim routing reintroduces the loser
  crash.
- **Fresh-key race test**: was `receipts != []` with the both-can-win TOCTOU disclosed. Now:
  `length(receipts) == 1`, every loser typed, subject quiescent, rotation leg unchanged.
  Mutation rationale: removing the claim routing re-admits the double stopped_at receipt.

## Commands + exits (real, PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW984ct)

```
mix compile                                                   → exit 0 (fresh root, full dep build)
mix test test/xaas/oversight/w984cf_oversight_depth_test.exs \
         test/xaas_web/quiescent_fabric_tie_test.exs          → 14 passed
mix test <same two files> test/xaas/actuation/ --seed 77234   → 27/30, 3 failed (pre-existing, see below)
mix test <oversight+tie+quiescent_stop_test+quiescent_stop_deepening> --seed 77234 → 19 passed
mix test <same> --seed 991                                    → 19 passed
mix test test/xaas/actuation/ --seed 991                      → 13/16, same 3 failed (pre-existing)
mix test test/xaas/oversight/w984cf_oversight_depth_test.exs --seed 0/1/2 → 5 passed ×3
```

## Pre-existing failures (NOT session-introduced, A/B verified)

`test/xaas/actuation/run_idempotency_deepening_test.exs` (d1)(d2)(d3) fail identically with my
diff swapped out for HEAD's `quiescent_stop.ex` (7/10 both ways, seeds 0 and 991): the tests
assert `Ash.read!(ActuationIntent, authorize?: false) == []` globally, and leaked
ActuationIntent rows from other suites (observed: a "Teacher-librarian spotlight pick" library
intent) persist in `xaas_test`, breaking the global-empty assertions. A/B with HEAD's file:
identical 7/10. Coordinator note: these tests need per-key filtering, not global-empty asserts,
and the row leak (likely OcelForwarder or non-transactional create) is its own defect.

## Transport failures / notes

- One corrupted Write of `quiescent/actuation/quiescent_stop.ex` mid-session (garbage placeholder
  text landed on disk twice); recovered by `git checkout HEAD -- <file>` and redoing the change
  as small Edits. Final on-disk content re-read and verified before compile.
- Build root `_build-laneW984ct` (~426 MB) left on disk for the coordinator — `rm -rf` denied by
  the permission system, same as W984cf's lane root; deletion is the coordinator's integration
  step (cleanup law).

## Standing

ALIVE — fix landed, pins flipped, target courts green ×5 seeds total; pre-existing failures
A/B-attributed to leaked ledger rows, not this lane's diff.
