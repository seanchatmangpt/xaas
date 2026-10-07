# W984dm Probe Receipt — Conference Attendee/Session Lifecycle Depth Court

Lane: W984dm, xaas v26.10.6 coverage burn-down. No commit (per lane law; files left
for coordinator).

## Disposition

Court landed: **Conference attendee/session lifecycle** (unclaimed family: conference
non-registration/non-event). Registration-journey and event surfaces were already held
(W893 enrollment court, W981s/W983a registration courts, `conference_test.exs`
seed-count census); the two *referenced* entities — `Xaas.Conference.Attendee` and
`Xaas.Conference.Session` — had no lifecycle court. Verified by grep: no test file
outside `test/xaas/conference/` touches either resource, and the two in-family files
only seed/count or exercise registration semantics.

## Court

File: `test/xaas/conference/attendee_session_lifecycle_court_w984dm_test.exs`
(5 tests, Chicago-style over real `Ash.DataLayer.Ets` tables, real Ash actions, no
mocks; mock gate `[]`).

1. **Attendee lifecycle** — create persists real row, inserted_at/updated_at are real
   `DateTime`s, get returns it, `Ash.destroy!` → subsequent `Ash.get!` raises the
   wrapped `Ash.Error.Invalid` ("not found"). Mutation rationale: no-op the destroy →
   the get succeeds, assert_raise never fires.
2. **Attendee unique_email** — duplicate create refused with real
   `Ash.Error.Invalid` "has already been taken"; refusal leaves exactly 1 row (no
   partial write). Mutation rationale: drop `identity(:unique_email, [:email],
   pre_check_with: Ash.DataLayer.Ets)` → duplicate row lands, single-row assert kills.
3. **Session capacity constraint** — `capacity: 0` refused with real
   `Ash.Error.Invalid` "must be greater than or equal to 1"; `nil` and `1` accepted;
   exactly 2 rows after. Mutation rationale: drop `constraints(min: 1)` → 0 create
   succeeds, assert_raise never fires.
4. **Session unique_slug** — duplicate slug (different speaker) refused with real
   `Ash.Error.Invalid` "has already been taken"; distinct slugs coexist (2 rows).
   Mutation rationale: drop `identity(:unique_slug, [:slug], pre_check_with:
   Ash.DataLayer.Ets)` → duplicate lands, single-row assert kills.
5. **Session destroy is non-cascading** — destroying a session leaves its referencing
   registration readable with the dangling `session_id` intact (pinning the documented
   non-cascading ETS contract; ResolveRegistrationRefs only guards at create time).
   Mutation rationale: add cascade destroy → registration deleted, readability assert
   fails.

## Census (as-of-run)

- `lib/xaas/conference/*.ex`: 7 resources, 689 lines total (attendee 56, event 60,
  registration 328, session 68, speaker 57, sponsor 62, track 58).
- Conference test files before this lane: `conference_test.exs` (seed+census only),
  `enrollment_journey_court_test.exs` (registration journey), plus W983c-era courts.
  Attendee/Session lifecycle: 0 prior tests.
- Sponsor/track lifecycle remains unclaimed for a later lane (thin CRUD, lower value).

## Verification (real commands, real exits)

Build root: `_build-laneW984dm` (fresh, full compile under
`PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`).

- Run 1: 3/5 passed — 2 failures, both mine (error-class/regex mismatches, not product
  defects): `Ash.get!` on destroyed row raises wrapped `Ash.Error.Invalid`, not bare
  `Ash.Error.Query.NotFound`; capacity min message is "must be greater than or equal
  to 1", not "min". Fixed the court, not the product.
- Run 2: 4/5 passed (regex fix pending on test 3, run interleaved).
- Run 3: **5 passed, exit 0** (final court shape, fresh root).
- Run 4: **5 passed, exit 0** — second consecutive full pass on the same court =
  fresh-root repeatability (×2).
- Mock gate:
  `scan_mock_usage(["test/xaas/conference/attendee_session_lifecycle_court_w984dm_test.exs"])`
  → `[]`.

## Standing

- Court: **ALIVE** — observed execution on the exact subject
  (`test/xaas/conference/attendee_lifecycle...w984dm_test.exs`), 5/5 twice, exit 0.
- Conference attendee/session lifecycle family: **COVERED** (5-test depth court).
- Sponsor/track lifecycle: **UNCLAIMED/thin** (documented census residue).
- No product defects found; both early failures were court-side assertion-shape
  corrections, disclosed above.

## Cleanup

Lane build root `_build-laneW984dm` deletion was denied by the permission system —
left in place for the coordinator (per lane law fallback), 426 MB at last measure.
