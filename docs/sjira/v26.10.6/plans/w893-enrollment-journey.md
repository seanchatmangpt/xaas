# W893 — Conference Enrollment Journey Court

Lane: W893, xaas v26.10.6 campaign, branch `feat/playwright-surface`.
Repo: `/Users/sac/xaas` (canonical checkout, no worktree).

## Subject

- New file: `test/xaas/conference/enrollment_journey_court_test.exs`
- Standing claim: the full Conference Registration journey works end-to-end
  over real Ash actions on real ETS tables, and the capacity/cancel
  semantics are exactly as pinned.

## Fence (what exists vs. what was asked)

- No conference/registration LiveView exists in `lib/xaas_web/live/`
  (verified by grep: zero hits for registration/conference/attendee). The
  flow is API/Ash-only → per the order, the court covers the Ash-level
  enrollment journey instead.
- Unit courts exist at W715/W795; this adds the journey-level court.

## μ / diff

Handwritten test file (1 file, ~210 lines), Chicago-style:
`event → track → speaker → session(capacity: 1) → attendee → registration
(refs resolved) → second registration REFUSED at capacity (1/1) →
update :registered → :cancelled (admitted forward edge) → third
registration STILL refused — the real behavior: `EnforceSessionCapacity`
counts all rows regardless of status, so cancel does NOT release the slot —
→ nil-capacity session accepts registrations (backward-compat path).
Asserts real rows via `Ash.get!`/`Ash.read!` end-to-end; no mocks.

## Commands / exits (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW893 \
  mix test test/xaas/conference/enrollment_journey_court_test.exs
# determinism run 1: "Result: 1 passed"  (0.3s sync)
# determinism run 2: "Result: 1 passed"

# mock gate:
mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(
  ["test/xaas/conference/enrollment_journey_court_test.exs"]))'
# => []
```

## Transport failures (real)

- First compile attempt (06:08–06:20) failed: sibling lane W902's in-flight
  edit to `lib/xaas/library/checkout.ex` (uncommitted W902 batch-3 borrow
  cap) did not compile (`undefined variable "status"`, `misplaced operator
  ^user_id`). Typed as BLOCKED(other-lane-WIP-compile-break). Polling: the
  sibling fixed it within ~2 minutes; compile went green and both test runs
  executed. No fix was applied from this lane (lib/ is outside lane
  ownership).
- Side note: one interim `mix compile` ran without MIX_ENV=test (default
  dev env, no --force, halted at the checkout.ex error). No `--force`, no
  successful dev artifacts written; risk of dev `_build` corruption
  assessed LOW but noted for the coordinator.

## Verification ladder

Narrow (single test file, real ETS + real Ash actions). Determinism ×2
run. Mock gate `[]`. Unit/integration courts W715/W795 remain the
component-level layer.

## Standing

ALIVE (this lane, exact subject, observed execution ×2).

## Typed gaps

- `GAP(NoLiveViewSurface)`: the order anticipated a LiveView registration
  flow; none exists — courted the Ash journey instead. Any future
  `RegistrationLive` needs its own court.
- `GAP(CancelDoesNotReleaseSlot)`: pinned real behavior — capacity counts
  `:cancelled` rows (`EnforceSessionCapacity` has no status filter).
  Product decision pending whether cancel should free the slot; the pinned
  assertion is the guard rail.
- `GAP(NoServerActionForCancel)`: cancel is a bare `:update` of `status`,
  not a named action (`:cancel`); forward-edge guard
  (`RegistrationStatusTransition`) is the only protection.

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW893 \
  mix test test/xaas/conference/enrollment_journey_court_test.exs
```

Lane build root `_build-laneW893` deleted post-run (coordinator: nothing
left behind). Not committed, per lane contract.
