# W969e — Legal-Walk Witness Court (multi-attendee slot cycling)

Lane: W969e · Repo: /Users/sac/xaas · Branch: feat/playwright-surface · Campaign: v26.10.6
Court added: `test/xaas/conference/enrollment_journey_court_test.exs`, test
`"W969e legal walk: A registers → B refused → A cancels → B succeeds → B cancels → A succeeds (repeated slot cycling)"`
(extended file only; existing W893 / W973b tests untouched).

## Court shape

Capacity-1 session, real Ash actions on real ETS tables (Chicago: no mocks):

1. A registers — slot taken (`:registered`).
2. B registers — typed refusal `at capacity (1/1 taken)`, nothing written
   (row count still 1).
3. A cancels via the named `:cancel` action (W947) — `:cancelled`, slot released (W925).
4. B registers — succeeds, new row id, slot released witnessed.
5. B cancels via `:cancel` — `:cancelled`, slot re-released.
6. A re-registers — **typed identity refusal `has already been taken`
   (unique_attendee_session)**, probed while the slot is FREE (before C sits).
7. C registers — succeeds: the SECOND slot release is witnessed, cycling proven
   beyond a single hand-off.
8. End-state determinism: exactly 1 active (`:registered`, C's), 2 `:cancelled`
   rows, 3 rows total — both refused creates (steps 2 and 6) wrote nothing.

## Falsifiers found (product-side, coordinator to close)

### GAP(same-attendee-re-register-blocked-by-identity)

The task-spec step 6 "A re-registers succeeds" is **REFUTED by measurement**:
`identity(:unique_attendee_session, [:attendee_id, :session_id], pre_check_with: Ash.DataLayer.Ets)`
(lib/xaas/conference/registration.ex:49) has no status scope, so A's cancelled
row blocks A's own return with `has already been taken` even when the capacity
slot is free. The second release is witnessed through attendee C instead; A's
blocked return is asserted as a typed observation (step 6). Product-side close:
scope the identity over active statuses, or add an explicit re-open action.

### Pre-existing RED: W973b terminal guard still unenforced

The W973b red-falsifier test ("a cancelled registration cannot :cancel again")
remains RED by measurement: `RegistrationStatusTransition` admits self-transitions
({:cancelled, :cancelled} via `:cancel`), so nothing is raised. Untouched per its
do-not-soften note. File total: 4 tests, 3 pass, 1 fail (the pre-existing falsifier).

## Determinism ×2 — real tails

Run 1 (EXIT 2, failure = pre-existing W973b falsifier only):

```
Finished in 0.6 seconds (0.00s async, 0.6s sync)
Result: 3/4 passed
Failed: 1 test
```

Run 2 (EXIT 2, identical):

```
Finished in 0.4 seconds (0.00s async, 0.6s sync)
Result: 3/4 passed
Failed: 1 test
```

Runs 3–4 failed at **compilation of lib/xaas/bridges/graphlaw.ex**
(TokenMissingError at line 203, foreign lane's in-flight edit in the shared
checkout — not this lane's file; runs 3–4 are not valid falsifiers of this court).

## Standing

- W969e legal-walk court: **ALIVE** — observed execution ×2 on exact subject
  (test file on feat/playwright-surface, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW969e,
  PATH=$HOME/.asdf/shims:$PATH).
- W925 slot release + W947 `:cancel` + repeated cycling: ALIVE (witnessed twice).
- Task-spec same-attendee re-registration: **REFUTED** —
  GAP(same-attendee-re-register-blocked-by-identity).
- W973b terminal guard (cancel of cancelled): **still RED**, guard not landed
  product-side; court preserved as failing observation.
- W893 unlimited-session leg + W973b cycling leg: untouched, passing in both runs.

## Cleanup

`rm -rf _build-laneW969e` was permission-denied for this lane; build root left
in place for coordinator deletion per the lane-lease law.
