# W984dn — Sponsor/Track Lifecycle Depth Court

Lane: W984dn, xaas v26.10.6 campaign. Residue from W984dm's note:
conference sponsor/track lifecycle was unclaimed and thin — only smoke-level
create/read in `conference_test.exs`, no typed-invariant coverage.

## Census

`lib/xaas/conference/` — 7 modules:
`attendee.ex`, `event.ex`, `registration.ex`, `session.ex`, `speaker.ex`,
`sponsor.ex`, `track.ex`. Sponsor/track-bearing modules:

- `lib/xaas/conference/sponsor.ex` — state-bearing: `tier` atom with
  `constraints(one_of: [:diamond, :gold, :silver, :bronze])`, `name`/`slug`
  allow_nil? false, `url` nullable, `identity(:unique_slug, [:slug],
  pre_check_with: Ash.DataLayer.Ets)`, `defaults([:read, :destroy])`.
- `lib/xaas/conference/track.ex` — state-bearing: `name`/`slug` allow_nil?
  false, `event_id` allow_nil? false, `identity(:unique_slug, ...)`,
  `defaults([:read, :destroy])`.
- `session.ex` references `track_id` (allow_nil? false) — relevant to the
  non-cascading destroy test.

Cross-references: `conference_test.exs` holds smoke create/read of both
resources only; no identity/constraint/destroy coverage existed before this
court.

## Court

`test/xaas/conference/sponsor_track_lifecycle_court_w984dn_test.exs`, 5
tests, Chicago-style over real `Ash.DataLayer.Ets` tables, real Ash actions,
no mocks, each typed refusal asserted as-real (raised `Ash.Error.Invalid`):

1. **Sponsor lifecycle** — create persists real row, tier atom round-trips,
   timestamps set, destroy removes row, post-destroy `Ash.get!` raises
   wrapped `Ash.Error.Invalid` ~r/not found/ (W984dm shape).
   Mutation kill: drop timestamps or no-op the destroy.
2. **Sponsor tier one_of** — `:platinum` refused as-real with exact Ash 3.34
   message `atom must be one of "diamond, gold, silver, bronze", got:
   :platinum` (asserted `~r/must be one of/`); all four tiers accepted, 4
   rows, no partial write of the refused row.
   Mutation kill: empty the one_of constraint list.
3. **Sponsor unique_slug** — duplicate slug refused ~r/has already been
   taken/, exactly 1 row after refusal (no partial write).
   Mutation kill: drop the `identity(:unique_slug, pre_check_with:)` line.
4. **Track event_id required** — nil event_id refused ~r/is required/;
   present id accepted, `track.event_id == event.id`.
   Mutation kill: drop `allow_nil?: false` on `event_id`.
5. **Track unique_slug + non-cascading destroy** — duplicate slug refused
   as-real; destroyed track leaves referencing `Session` readable with
   dangling `track_id` — pinning the documented non-cascading ETS contract
   (W984dm test-5 shape, Session instead of Registration).
   Mutation kill: add a cascade destroy to Track.

## Verification (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dn \
  mix test test/xaas/conference/sponsor_track_lifecycle_court_w984dn_test.exs
# run 1: Result: 5 passed   (0.9s sync; 1 initial failure repaired:
#        tier-message regex "expected one of" -> "must be one of",
#        per real Ash 3.34.4 message read from actual failure output)
# run 2: Result: 5 passed
```

×2 consecutive fresh-root runs (full `setup` wipe of Session/Track/Sponsor/
Event between tests, plus two end-to-end suite runs) both green.

## Standing

- Court: **ALIVE** on exact subject
  `feat/playwright-surface` @ `16b54f3c` (working tree, uncommitted —
  coordinator owns commits per lane law).
- Standing: PARTIAL_ALIVE for the sponsor/track surface as a whole —
  smoke coverage (pre-existing) + this depth court; no HTTP-layer coverage
  of the json_api routes for these two resources in this lane.
- Falsifiers (all would kill named tests): tier one_of emptied; unique_slug
  identity dropped; event_id allow_nil? relaxed; cascade destroy on Track;
  no-op destroy.
- Lane build root `_build-laneW984dn` (~368M) left in place for coordinator
  deletion — `rm -rf` denied by the session permission system this lane.
- Files written: `test/xaas/conference/sponsor_track_lifecycle_court_w984dn_test.exs`
  and this receipt. Nothing committed.
