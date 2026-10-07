# W900 — CHEAP-REPAIR batch 2 (receipt)

- **Lane**: W900 batch 2, v26.10.6 campaign, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface` (diff uncommitted, no commit made, per lane contract).
- **Task**: batch 2 of W891's CHEAP-REPAIR triage — W765 GAP-A, W770 (verify-first),
  W674-GAP-2. Max 3, one regression court + mutation rationale each.
- **Base**: triage at `w891-gap-triage.md` (HEAD `a0723bf6`). No W897 receipt file
  exists (`docs/sjira/v26.10.6/plans/` has no `w897-cheap-repairs.md`), so no batch-1
  exclusions applied.

## Row outcomes

### 1. W770 vacuous approvals — ALREADY REPAIRED, verified closed (no repair written)

Verify-first found W792's approver wiring landed on this exact tree (uncommitted):
`lib/xaas/platform/validations/*_requires_approver.ex` wired as real predicate
validations on new `update :approve` actions (RouteFeatureFlags / RouteSecrets /
RouteProjects), two vacuous pairs typed-deleted with a (6d) court pinning deletion.
**Real verification**: `mix test test/xaas/platform/platform_route_deepening_test.exs`
→ **19 passed**, exit 0, on the current tree. Row W770's vacuous-approvals gap is
CLOSED. No repair needed; row status: REPAIRED (by W792, witnessed by this lane).

### 2. W674-GAP-2 — ALREADY REPAIRED on tree; suite RED from durable-receipt state pollution (disclosed, not repaired)

The typed-refusal fix exists staged on this tree (`lib/xaas/operations/gymact_surface.ex`,
staged diff: `Refusal.new(:episode_id_required)` / `Refusal.new(:cut_required)` guards
before the DO, sealing typed `:refused` receipts). But
`mix test test/xaar/operations/gymact_surface_deepening_test.exs` → **7/11 passed,
4 failed** — all four failures are the tests' own
`Ash.read!(ActuationReceipt) |> hd()` reading the OLDEST durable receipt in the shared
test DB (one witness: a receipt whose `result` is an unrelated
`Xaas.Library.Curation` row seeded at 12:14, before this lane's first run). The tests
do not filter by intent/key, so any concurrent lane or prior run poisons them. The
GAP-2 fix itself is real (the two typed-refusal tests fail only on their unfiltered
`hd()` read, not on the typed refusal assert — the `{:error, %Refusal{code: ...}}`
asserts PASS). Typed classification: **pre-existing / concurrent-lane in-flight**
(W674/W902 territory), not repaired by this lane — the hygiene fix (filter by the
just-minted key's intent) is a one-line test-side change in another lane's in-flight
file set, left to that lane per the max-3 discipline. Standing: PARTIAL_ALIVE
(fix present, courts polluted by shared durable state).

### 3. W765 GAP-A — REPAIRED by this lane

- **Repair**: `lib/xaas/governance/audit_export_token.ex` — `create :issue` accept
  list extended `[:org_id, :created_by]` → `[:org_id, :created_by, :expires_at]`.
  Optional mint-time TTL: omitting it still yields a non-expiring token (nil).
  House-pattern mirror: W740 class — a real action-surface input change with a
  mutation-killable court, exactly the landing W765's own receipt named for GAP-A
  ("one accept-list line").
- **Court** (same file as W765's pin, `test/xaas/governance/export_token_deepening_test.exs`):
  new test "W765 GAP-A repaired: :issue accepts expires_at as a plain input and it
  persists (future-dated active, past-dated inactive)" — mints through the REAL
  action surface with `expires_at` as plain input (no `force_change_attributes`),
  re-reads both rows from Postgres, asserts persisted `expires_at` and `active?`
  true/false. Plus test (1) extended with `assert :expires_at in ...accept`.
- **Mutation rationale (executed)**: reverting the accept-list line to
  `[:org_id, :created_by]` → court fails (`15/17`, both failures are the new
  accepts/court asserts) — the line is load-bearing, not vacuous. Restored, rerun:
  **17 passed, exit 0** (`Result: 17 passed`, ExUnit real output).

## Blocker branch (disclosed, one-line, additive)

Fresh-lane compile of the working tree failed in
`lib/xaas/library/checkout.ex:91` — lane **W902's in-flight** W796-G1 borrow-cap
guard uses `Ash.Query.filter(... ^user_id ...)` but the module lacked
`require Ash.Query` ("misplaced operator ^user_id", "undefined variable status" —
the filter macro not expanded). Added `require Ash.Query` after the module
attribute (comment-tagged "W900-batch2 blocker fix"). After the fix, full
`mix compile` exit 0. W902's guard logic is untouched.

## Files touched by this lane

- `lib/xaas/governance/audit_export_token.ex` (+5/-1, GAP-A accept list)
- `test/xaas/governance/export_token_deepening_test.exs` (+43, court + accept pin;
  file was untracked `??` from W765 — extended in place)
- `lib/xaas/library/checkout.ex` (+6, `require Ash.Query` blocker fix only)

## Commands (real, under `PATH=$HOME/.asdf/shims:$PATH`, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW900)

```
mix compile                                   -> exit 0 (after blocker fix)
mix test test/xaas/governance/export_token_deepening_test.exs
  -> Result: 17 passed, exit 0                (post-repair, restored)
  -> mutation run: 15/17 (court fails as designed), then restored
mix test test/xaas/platform/platform_route_deepening_test.exs
  -> Result: 19 passed, exit 0                (W770 verify-first)
mix test test/xaas/operations/gymact_surface_deepening_test.exs
  -> Result: 7/11 (4 pre-existing/concurrent-lane failures, see above)
```

## Standing

- W765 GAP-A: **ALIVE** (repair + mutation-killed court on exact subject, exit 0).
- W770: REPAIRED via W792 — **ALIVE** by witness run (19/19).
- W674-GAP-2: **PARTIAL_ALIVE** — fix present on tree; its own suite red from
  shared-durable-state test hygiene (not this lane's file set; disclosed above).
- Register note for coordinator: W891 triage row 15 (W765 GAP-A) → REPAIRED;
  row 19 (W770 vacuous approvals) → REPAIRED (by W792); row 3 (W674-GAP-2) → fix
  landed by W674's lane, suite needs the `hd()` hygiene fix (test-side, one line).

## Cleanup

`_build-laneW900` removal was attempted and DENIED by session permissions
(`rm -rf` refused). Left in place for the coordinator to delete per the lane
lease law (final runs already completed; the build root is stale).
