# W984aa — Depth Batch 2 (governance / semantics / operations)

Lane W984aa, xaas v26.10.6 campaign. Branch `feat/playwright-surface`, lane start
HEAD `5f7f70d9`. No commit (per dispatch). Wrote only: 3 new test files + this
receipt.

## Surface selection (read-first; all verified uncovered via test-tree grep)

- **governance (non-freeze, non-approval):** `Xaas.Governance.PentestFinding`
  — the pre-existing `pentest_finding_test.exs` (4 tests) runs every court
  with `authorize?: false`; the AUTHORIZED paths through
  `PentestFindingActorOrgMatches` (SimpleCheck on `:create`) and
  `PentestFindingActorOrgFilter` (FilterCheck on `:remediate`) have zero
  coverage. (The `approval_pentest_finding_resolve_*` tests court the
  approval, not the finding resource's own policy layer.)
- **semantics (non-dataset_admission):** `Xaas.Semantics.RobustMargin` —
  `robust_margin_test.exs` (8 courts) covers the happy paths and the W676
  malformed-margin regression, but the W630 typed-overflow rescues, the
  coincident-pairs zero-slope guard, the exact-zero-margin `>= 0` boundary,
  epsilon-monotonicity, and the negative-constant guard-domain refusals are
  uncourted. (Every other semantics module has at least one file; this one's
  remaining slice is boundary/typed-refusal edges.)
- **operations (non-incident/castle-run):** the read-only castle-verb
  inventory trio (`CastleVerbInventoryGoals`, `CastleVerbInventoryComponents`,
  `CastleVerbFortune5Requirements`) — prior coverage is a single
  module-name mention inside `system_authority_service_scope_test.exs`; no
  resource-level court exists anywhere in the test tree.

## Files + per-file counts (all green ×2)

| file | tests | result |
|---|---|---|
| `test/xaas/governance/pentest_finding_authorization_depth_test.exs` | 5 | 5/5 ×2 |
| `test/xaas/semantics/robust_margin_depth_test.exs` | 6 | 6/6 ×2 |
| `test/xaas/operations/castle_verb_inventory_policy_floor_test.exs` | 5 | 5/5 ×2 |
| **combined** | **16** | **16/16 ×2** |

Note: dispatch asked 5 tests/court; the semantics court carries 6 (the
negative-constant guard-domain refusals are one extra test worth its own
mutation target — the catch-all clause) — disclosed here rather than trimmed.

## Commands (real tails)

`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984aa
mix test test/xaas/governance/pentest_finding_authorization_depth_test.exs
test/xaas/semantics/robust_margin_depth_test.exs
test/xaas/operations/castle_verb_inventory_policy_floor_test.exs` —
real final tails (both runs):

```
................
Finished in 0.5 seconds (0.08s async, 0.4s sync)

Result: 16 passed
```

Run 2 identical: `Result: 16 passed` (0.3s). Logs: `/tmp/w984aa-run1.log`,
`/tmp/w984aa-run2.log` (session-scoped; not durable).

## Mutation rationale per court

1. **governance**: revert either check's `match?/filter` to `true`, or drop
   the per-action bypasses from `pentest_finding.ex`'s policies block, and
   courts (2)/(4)/(5) fail while same-org courts (1)/(3) stay green —
   policy-shaped vs action-shaped refusal distinguished; reverting the
   twenty-first-pass ERRC fix fails exactly the cross-org courts.
2. **semantics**: delete either `rescue ArithmeticError` clause → courts
   (1)-(2) crash raw instead of typed; delete the `denominator == 0` guard →
   court (3) badarith; flip `>= 0` → `> 0` → court (4) exact-zero-margin
   flips to refusal while the monotonicity sweep (court 5) stays green;
   drop the guard-domain catch-all → court (5b) raises FunctionClauseError.
3. **operations**: add `:create` to `defaults([...])` in any of the three
   resources and courts (2)/(3) fail — the write surface becomes real and
   the `policy always() forbid` floor must then be the refuser; drop the
   `bypass action_type(:read)` and courts (1)/(4) fail on the anonymous
   authorized read; drop the json_api block and court (5) fails on the
   Info.type/routes drift guard.

## Chicago discipline

Real sandboxed Postgres rows via real Ash actions (`authorize?: true` actor
courts — the first authorization-layer coverage PentestFinding has had) or
real `Repo.insert_all` + real Ash reads; semantics court runs the real
module with real float-boundary arithmetic, no doubles. Mock gate: grep of
the three files for `Mock()/mock()/patch(` → **0 matches**.

## Standing + disclosed lane events

- Standing: **ALIVE** for all 3 courts on the exact subject
  (branch `feat/playwright-surface`, lane start `5f7f70d9`).
- Disclosed shared-tree event (not mine, not fixed by me): another lane
  removed `ash_graphql` + `absinthe_plug` from `mix.exs` mid-session; my
  lane root's xaas `.app` was stale-compiled
  against the old dep graph, surfacing as `Could not start application
  ash_graphql`. Unblocked without touching the shared tree by
  `mix compile --force` **inside my lane build root only**. Initial-run
  failures (1 arg-error shape fix in the operations court, 1
  `AshJsonApi.Resource.Info` deprecation fix, 1 list-diff `--` semantics
  fix) were all in the new test files, repaired, and green before the two
  reported consecutive green runs.
- Build root `_build-laneW984aa` left in place for coordinator deletion
  (`rm -rf` denied by the permission system for this lane).
