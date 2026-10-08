# W984fj probe receipt — Castle/Route-verb operations burn-down

Lane W984fj · repo /Users/sac/xaas · branch feat/playwright-surface · 2026-10-07 · no commit.

Subject: court file `test/xaas/operations/castle_verb_court_w984fj_test.exs` (new, this lane).

## Per-module dispositions (12 modules, all re-read from disk)

All six consumer resources (`Xaas.Operations.RouteCastleDeploy`,
`RouteCastleRun`, `RouteCastleSchedule`, `RouteCastleSunset`,
`CastleVerbInventoryComponents`, `CastleVerbInventoryGoals`) are
read-only (`defaults([:read])`; `RouteCastleRun` additionally has the
private, unrouted `:execute`, courted by W858's
`route_castle_run_surface_test.exs`). Their resource surfaces were
already covered by W984dk (castle_approval_route_surface_test) and the
policy-floor courts; the census-uncovered surface is the 12 thin
change/validation modules:

| module | lines | behavior | disposition |
|---|---|---|---|
| Changes.RouteCastleDeployApprove | init + identity change | no-op, unwired | courted (identity + init + unwired) |
| Changes.RouteCastleRunApprove | same | no-op, unwired | courted |
| Changes.RouteCastleScheduleApprove | same | no-op, unwired | courted |
| Changes.RouteCastleSunsetApprove | same | no-op, unwired | courted |
| Changes.CastleVerbInventoryComponentsApprove | same | no-op, unwired | courted |
| Changes.CastleVerbInventoryGoalsApprove | same | no-op, unwired | courted |
| Validations.RouteCastleDeployRequiresApprover | init + validate -> :ok | no-op, unwired | courted |
| Validations.RouteCastleRunRequiresApprover | same | no-op, unwired | courted |
| Validations.RouteCastleScheduleRequiresApprover | same | no-op, unwired | courted |
| Validations.RouteCastleSunsetRequiresApprover | same | no-op, unwired | courted |
| Validations.CastleVerbInventoryComponentsRequiresApprover | same | no-op, unwired | courted |
| Validations.CastleVerbInventoryGoalsRequiresApprover | same | no-op, unwired | courted |

Key finding (CamelCase grep over lib/, `command grep`, W984er-safe):
each of the 12 module names occurs ONLY in its own file — unlike the
W984dr2b `*RequiresApprover` family, none is wired into any resource
action. The court asserts this as an invariant (tests 3+4), so a later
`:approve` action or a wired vacuous validation flips the assertion.

## Court contents (6 tests, all passing)

1. census self-check: all 12 modules enumerated and loaded.
2. `*Approve` identity: `init/1` passthrough (both `[]` and opts) +
   `change/3` returns a real `ApprovalCastleVerbSchedule` create
   changeset unchanged (struct-equality pin `^changeset`).
3. `*RequiresApprover` identity: same init pins + `validate/3 -> :ok`
   on real changesets with `approved_by` nil and populated (the
   module's entire branch surface).
4. wiring court: each consumer resource's action surface asserted
   exactly (`[:read]`, Run `[:read, :execute]`) — any added
   approve/write action fails.
5. source-wiring court: CamelCase symbol grep over lib/ excluding each
   module's own file — no wiring site may appear.
6. boundary probe: repo-minted rows in all six tables readable via
   `Ash.get!`, update-action-absent refusal (ArgumentError), row
   byte-identical after.

Mutation rationale: identity mutation (a no-op that starts mutating
changesets) fails tests 2/3; wiring mutation (a vacuous no-op
validation wired onto a real `:approve`) fails tests 4/5; write-surface
mutation fails tests 4/6.

## Verification (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984fj
  mix test test/xaas/operations/castle_verb_court_w984fj_test.exs`
  -> `6 passed` (first run: 5 passed + 1 Ash changeset-mutation
  warning in test 2, fixed to changeset-before-for_create pattern;
  rerun clean, exit 0).
- Mock gate: `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'`
  -> `[]`.
- Chicago: real sandboxed Postgres, real Ash changesets/actions, zero mocks.

## Transport failures

- Lane build root compile of the fresh `_build-laneW984fj` exceeded the
  600s foreground cap; rerun in background, completed exit 0.
- `rm -rf _build-laneW984fj` cleanup DENIED by the harness permission
  system — the lane build-root lease remains on disk for the
  coordinator to delete at integration (fanout cleanup law).

Standing: PARTIAL_ALIVE — court passes on the exact lane subject;
receipt unsealed, no commit (per lane contract).
