# W947 — Named `:cancel` action on Registration

Lane W947, campaign v26.10.6. Closes W893 `GAP(NoServerActionForCancel)` +
W946c register row: registration cancel was a bare `:update` with
`%{status: :cancelled}`; now a named `update :cancel` exists.

## Diff

- `lib/xaas/conference/registration.ex`: added `update :cancel`
  (`accept([])`, `require_atomic?(false)`, shared W795
  `RegistrationStatusTransition` validation, force-change to `:cancelled`).
  No json_api wiring needed — the block exposes only get/index/post on
  :read/:create; it exposes no update routes.
- `test/xaas/conference/enrollment_journey_court_test.exs`: cancel step
  flipped from `for_update(reg, :update, %{status: :cancelled})` to
  `for_update(reg, :cancel, %{})`.

## Verification

Toolchain: asdf pinned shims, `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW947`.

- Run 1: `mix test test/xaas/conference/` → `Result: 4 passed` (0 failed)
- Run 2: `mix test test/xaas/conference/` → `Result: 4 passed` (0 failed)
- Mutation (rationale): removed the `:cancel` action (bare-update-only
  revert), kept the court on `:cancel` → `Result: 0/1 passed` — court killed.
- Post-restore: `mix test test/xaas/conference/` → `Result: 4 passed`

## Standing

- ALIVE on this lane's uncommitted working tree (not committed — coordinator
  owns the commit per lane contract).
- Before: cancel reachable only via bare `:update`; after: named `:cancel`
  with forward-only guard, court witnesses it.

## Cleanup

`_build-laneW947` deletion was permission-denied in this lane; left for
coordinator per fallback in the lane contract.
