# W969c — DESIGN wave 3 receipt

Lane W969c, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`
(HEAD at lane start: `fab56ae1`). No commit made, per lane contract; the diff is left in
the working tree for the coordinator. Standing: PARTIAL_ALIVE.

## Spec selection history

1. Initial backlog pick from `docs/sjira/v26.10.6/plans/w905-design-gap-specs.md`:
   SPEC-27 (Ledger `:reverse`) and SPEC-14 (liveness `previous_status`). The wave-1/2
   receipts (`w968c-design-wave1.md`, `w969b-design-wave2.md`) were not landed at lane
   start (verified absent by ls). Live disk then showed W968c actively landing exactly
   those two specs: migrations `20261007230000_add_reverses_transfer_id_to_ledger_transfers.exs`
   and `20261007231000_add_previous_status_to_capability_liveness_receipts.exs` landed at
   07:34, and `transfer.ex` / `capability_liveness_receipt.ex` modified at 07:35 with
   `:reverse` and `previous_status` present. I backed my SPEC-27/14 drafts out; no
   duplicate implementation remains.
2. Second pick SPEC-18 (freeze-window runtime gate). I drafted
   `Xaas.Governance.Validations.FreezeWindowActive` wired onto
   `ApprovalEnvironmentPromote :approve`, then found lane W969b concurrently landing
   SPEC-18 as the policy check `Xaas.Governance.Checks.FreezeWindowActive` (fail-closed,
   `forbid_if` inside the `:approve` bypass on `ApprovalEnvironmentPromote` and
   `ApprovalDeploymentQuarantine`). I deleted my duplicate validation module and removed
   my `validate(...)` line from the resource; my remaining edit in that file is a
   moduledoc credit line naming lane W969b.
3. Final: SPEC-21 (RouteProjects `:create`) landed. Second spec REFUSED(disjointness):
   every remaining M spec was claimed or banned — SPEC-04/18 (W969b, on disk 07:38-07:40),
   SPEC-27/14 (W968c, on disk 07:34-07:35), SPEC-16/17 (landed pre-lane, w935 receipts),
   SPEC-20 (in-flight 07:38, untracked validation file), SPEC-07 (banned: `subscription.ex`
   lane-modified), SPEC-24/26/32 (banned surfaces), SPEC-30 (no direct `absinthe_plug`
   dep and `mix.exs` lane-modified).

## What landed (SPEC-21, W770-GAP-3)

- `lib/xaas/platform/route_projects.ex`: added `create :create do accept([:requested_by]) end`
  plus `bypass action(:create) authorize_if SystemActor`, with the W792 "create-less"
  disclosure comments flipped (updated, not deleted).
- `lib/xaas/checks/system_actor.ex`: added `{Xaas.Platform.RouteProjects, :create}` to
  `@internal_api_actions`. Without the exact-subject map entry the deny floor refuses
  `:create` even for `:internal_api` (observed as real `Ash.Error.Forbidden` in run 1).
- `test/xaas/platform/platform_route_deepening_test.exs`: test (5) flipped from pinning the
  create-less gap to asserting the real create surface; test (6c) comment updated;
  moduledoc bullet flipped.
- `lib/xaas/governance/approval_environment_promote.ex`: net change is only the moduledoc
  credit line for lane W969b's freeze check (my SPEC-18 duplicate fully backed out).
- New court `test/xaas/platform/route_projects_create_court_test.exs` (5 tests, mutation
  rationale in moduledoc): (a) real mint through policy with persisted row; (b) non-system
  actor refused typed `Ash.Error.Forbidden`; (c) wrong-service system authority refused;
  (d) create-then-approve maker-checker pair end-to-end (self-approve refused, distinct
  approver persists); (e) `:create` accept list excludes `:approved_by` (a pre-approved
  mint would bypass maker-checker).

## Verification (green x2)

Both runs under `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`,
`MIX_BUILD_ROOT=_build-laneW969c`:

- `mix compile`: exit 0 (warnings only; one references another lane's file).
- Run 1: `mix test test/xaas/platform/route_projects_create_court_test.exs
  test/xaas/platform/platform_route_deepening_test.exs` — 24/25 passed. My tests 6/6
  green (5 court + test 5). The single failure is "(4c) W970b/W770 retention sweep
  purge_expired" on `RouteProjectsBackups` — another lane's in-flight SPEC-20 test in the
  shared deepening file, a block I never touched.
- Run 2: identical result, 24/25, same single non-mine failure. Deterministic.

## Disclosure

- Concurrent failures observed (not introduced by this lane): the W970b retention-sweep
  test failure in the shared deepening file, identical in both runs.
- Cleanup: `_build-laneW969c` deleted at integration per the cleanup law.
- No commit; the coordinator owns integration and commits.

## Integration addendum (08:10, post-verification)

The coordinator integrated this lane in commit `b2758300` ("W969c SPEC-21 route create +
W970b hold checkout/retention/castle link"). Committed there: `route_projects.ex`,
`platform_route_deepening_test.exs`, `route_projects_create_court_test.exs`.
NOT committed there, still modified in the working tree at 08:10:
`lib/xaas/checks/system_actor.ex`, which carries
`{Xaas.Platform.RouteProjects, :create}` in `@internal_api_actions`. Until that hunk is
committed, `:create` on RouteProjects is refused `Ash.Error.Forbidden` even for
`:internal_api`, and the committed courts `route_projects_create_court_test.exs` (a)/(d)
plus deepening test (5) fail at HEAD. The working tree IS green (verified 24/25 x2 above,
including the map entry).
