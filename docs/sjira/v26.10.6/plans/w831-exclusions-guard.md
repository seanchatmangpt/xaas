# W831 — exclusions guard: refuse bare-binary exclusions (route surface)

- **Lane**: W831, v26.10.6 campaign, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`, HEAD at start `a0723bf6` (no commit made, per dispatch).
- **Source order**: W810 pinned gap, `docs/sjira/v26.10.6/plans/w810-route-surface.md`.
- **Standing**: PARTIAL_ALIVE (fix implemented + suite green ×2 in-lane; uncommitted,
  integration/commit owned by coordinator).

## Change

`lib/xaas/sa2a/route.ex` — `admit_field("exclusions", ...)`:

- Before: only `nil` → `{:ok, []}` and `is_list` clauses existed; a bare binary
  (or any other non-list) fell through to the generic `nonempty?` clause and was
  accepted verbatim into the tuple, contradicting `@type route_tuple`.
- After: a terminal `admit_field("exclusions", _value)` clause (placed *after*
  the `is_list` clause) routes any non-list to the existing typed refusal
  `{:refused, {:invalid_field, "exclusions"}}`. Refusal vocabulary unchanged —
  the set stays closed.

## Test conversion (regression court)

`test/xaas/sa2a_route_surface_test.exs` — the pinned-gap test
"a non-list exclusions value is accepted verbatim (pinned gap)" converted to
"a bare binary exclusions value is refused (former pinned gap)", asserting the
typed refusal. Mutation rationale inline: if the refusal clause reverts to the
fall-through behavior, the first assert fails — `Route.tuple(:task, bad)`
returns `{:ok, %{"exclusions" => "no deploy"}}` instead of
`{:refused, {:invalid_field, "exclusions"}}`.

## Verification (real runs, real tails)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW831
  mix test test/xaas/sa2a_route_surface_test.exs`
  - Run 1: `Result: 25 passed` (0 failures)
  - Run 2: `Result: 25 passed` (0 failures)
- No compile break from the sibling lane's parked
  `lib/xaas/operations/validations/incident_resolved_is_terminal.ex` — wait-and-retry
  and parked-file technique not needed.
- `MIX_BUILD_ROOT=_build-laneW831` NOT deleted: the `rm -rf` was denied by the
  permission system in this lane session. The directory remains on disk for the
  coordinator to remove at integration (lane-lease cleanup law).

## Note for integrator

First in-lane run after adding the refusal clause had it placed *before* the
`is_list` clause, shadowing valid lists (7 failures, all `{:refused,
{:invalid_field, "exclusions"}}` on well-formed fixtures). Root cause: Elixir
function-clause ordering. Fixed by reordering (nil → is_list → catch-all);
final code verified green ×2 above. The committed state is the corrected order.
