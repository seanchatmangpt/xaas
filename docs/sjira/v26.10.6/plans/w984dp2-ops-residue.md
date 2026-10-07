# W984dp2 — Operations residue slice (lane receipt)

**Lane**: W984dp2, repo `/Users/sac/xaas` (branch `feat/playwright-surface`, uncommitted
per lane law — no git state commands run).
**Date**: 2026-10-07. **Env**: asdf shims, `MIX_ENV=test`,
`MIX_BUILD_ROOT=_build-laneW984dp2` (fresh root, built from scratch this session).

## Subject

W984cw4's census: Operations 29→28 uncovered modules, remainder typed UNKNOWN. Slice:
`RouteCastleDeploy`, `RouteCastleSchedule`, `RouteCastleSunset`,
`ApprovalCastleVerbSchedule` (+ W984dk overlap check).

## Overlap check (W984dk)

No `w984dk-*.md` receipt on disk under `docs/sjira/v26.10.6/plans/`, but W984dk's TEST
file `test/xaas/operations/castle_approval_route_surface_test.exs` IS landed (182 lines,
5 courts). Its coverage: maker-checker happy path (create → approve as internal_api),
self-approval and missing-approver typed refusals, the route_castle trio reads via real
Ash actions, and the absent-write-surface `ArgumentError` refusals. This lane's courts are
disjoint: the *authorization* surface W984dk never ran (SystemActor bypasses, deny floor,
anonymous reads, create accept list).

## CamelCase-aware census (grep, test/**, both naming conventions)

Pre-lane (excluding this lane's file):

| module | camel refs in test | snake refs | first behavior court |
|---|---|---|---|
| `Xaas.Operations.RouteCastleDeploy` | 2 (W984dk) | 1 | W984dk (4)/(5) |
| `Xaas.Operations.RouteCastleSchedule` | 2 (W984dk) | 1 | W984dk (4)/(5) |
| `Xaas.Operations.RouteCastleSunset` | 2 (W984dk) | 1 | W984dk (4)/(5) |
| `Xaas.Operations.ApprovalCastleVerbSchedule` | 6 (W984dk 4 + name-only in `system_authority_service_scope_test.exs`:61-62) | 1 | W984dk (1)-(3) |
| `Xaas.Operations.RouteCastleRun` | many | many | out of slice (different module) |

## Court

**`test/xaas/operations/approval_castle_verb_schedule_authority_test.exs`**

Courts the best of the four (the only one with a real mutation surface + policy checks),
5 tests, real Postgres (sandbox), real Ash actions, typed refusals as-real
(`%Ash.Error.Forbidden{}` pattern-matched), no mocks:

1. **anonymous `:create` refused typed, nothing persisted** — `{Xaas.Checks.SystemActor,
   []}` create bypass is the only authority; SQL `Repo.exists?` proves nothing persisted.
   Mutation rationale: remove the `bypass action(:create)` and this court fails (no
   mutation authority survives).
2. **anonymous `:approve` refused typed, row unchanged** — denied before the
   RequiresApprover validation even runs; reloaded row byte-identical. Mutation: replace
   the approve bypass with `authorize_if(always())` → anonymous mutation admitted (the
   exact XAAS-2602 regression).
3. **anonymous read admitted via the read bypass** (`authorize?: true`, actor nil) —
   proves the deny floor does not cover reads. Mutation: drop `bypass action_type(:read)`
   → this court fails.
4. **`approved_by` accepted at `:create` (accept list)** — pre-approval at creation
   persisted, then re-approval by a second checker flows through `:approve` under the
   real system actor. Mutation: drop `:approved_by` from the accept list → court fails.
5. **non-system actor value (plain string actor) refused on `:approve`**, row unchanged —
   the SystemActor check refuses non-mapped actors fail-closed. Mutation: drop the deny
   floor `policy always() do forbid_if(always()) end` → a non-mapped action would fall
   open and this court fails.

## Typed disposition — genuinely thin remainder

`RouteCastleDeploy`/`RouteCastleSchedule`/`RouteCastleSunset` are byte-identical
read-only skeletons (52 LOC each, `defaults [:read]`, read bypass + deny floor, no
actions to mutate, no validations). Combined with W984dk's courts (reads via real Ash
actions, absent write surface, deny-floor refusals) there is no unexercised behavior
surface. Disposition: **THIN — READ-ONLY SKELETON, FULLY COURTED (W984dk), no further
lane work**. `ApprovalCastleVerbSchedule`:
**COURTED — W984dk (5 tests) + W984dp2 (5 tests) = 10 tests, zero overlap**, both files
pass together 10/10 in one run.

## Commands / exits (real output)

```
mix run census (fresh lane root build)   — app compiled; exit 1 from PromEx/Grafana uploader only (no Grafana in sandbox); census numbers taken from equivalent grep census
grep census (test/**): RouteCastle* trio 2/2/2 camel refs, all W984dk; ApprovalCastleVerbSchedule 6 camel refs (W984dk + name-only)
mix test test/xaas/operations/approval_castle_verb_schedule_authority_test.exs   → 5 passed (run 1)
mix test test/xaas/operations/approval_castle_verb_schedule_authority_test.exs   → 5 passed (run 2)
mix test <new file> <W984dk file>                                                → 10 passed, exit 0
```

×2 fresh root satisfied: two green runs of the new file on the fresh
`_build-laneW984dp2` root, plus a combined 10/10 run with W984dk's file.

## Standing

- New test file: **ALIVE** — executed on real Postgres/Ash/ETS-free path, 5/5 ×2 + 10/10
  combined.
- `ApprovalCastleVerbSchedule`: **ALIVE** (behavior + authorization surface courted).
- RouteCastle trio: **THIN — fully courted via W984dk; no residue** typed disposition.
- Census count correction: W984cw4's "operations 29→28" counted these 4 as uncovered;
  with W984dk's file landed, they were already covered pre-lane; this lane adds the
  disjoint authorization surface, not duplicate coverage.

## Cleanup

`_build-laneW984dp2` deletion was attempted and **denied by the permission gate** —
left in place for the coordinator to remove (`/Users/sac/xaas/_build-laneW984dp2`).
No commits made; writes confined to `test/xaas/operations/` + this receipt, per lane law.
