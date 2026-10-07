# W973b — Journey Wave 3: composed cancel/slot-release journey + terminal guard

Lane: W973b (xaas v26.10.6). Files touched (extend-only):
- `test/xaas/conference/enrollment_journey_court_test.exs`

## Standing

**PARTIAL_ALIVE — 1 BLOCKED sub-claim.**

## Executed

- Extended the W893 journey court with two tests:
  1. `W973b journey: register → cancel → re-register → cancel → re-register`
     — composed leg over the named W947 `:cancel` action, with W925 slot
     release witnessed twice through it (two distinct attendees admitted
     into the freed slot). GREEN.
  2. `W973b terminal guard: a cancelled registration cannot :cancel again`
     — asserts a typed refusal on the second `:cancel`. RED (measured).

## Key findings (measured, not inferred)

1. **`unique_attendee_session` identity holds across cancelled rows**
   (`pre_check_with: Ash.DataLayer.Ets`): the same attendee CANNOT
   re-register after cancelling — create raises
   `Ash.Error.Invalid: "attendee_id, session_id: has already been taken"`.
   So the W925 slot release is witnessed by a NEW attendee taking the freed
   slot (same shape as the W893 leg), not same-attendee re-registration.
   If the campaign intends same-attendee re-enrollment, that is an open
   product gap (identity needs a status-conditioned upsert).
2. **The W795 "cancelled is terminal" guard does NOT exist in the product.**
   `Xaas.Conference.Validations.RegistrationStatusTransition` admits
   self-transitions `{s, s}`, so `{:cancelled, :cancelled}` via `:cancel`
   is admitted with no refusal. Test 2 is therefore kept RED as the named
   falsifier (annotated in the test comment) — closing it requires a
   product-side change in
   `lib/xaas/conference/registration.ex` (outside this lane's file set).

## Verification (real tails, deterministic ×2)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW973b \
  mix test test/xaas/conference/enrollment_journey_court_test.exs

  1) test W973b terminal guard: a cancelled registration cannot :cancel again
     (typed refusal) ... Expected exception Ash.Error.Invalid but nothing was raised

..
Finished in 0.4 seconds
Result: 2/3 passed, 1 failed
```

Run 2: identical output (`2/3 passed, 1 failed`, same single failure). The
green 2/3 set (W893 journey + W973b journey) is deterministic ×2.

## Receipt

- Subject: feat/playwright-surface working tree, lane W973b, no commit (per dispatch).
- μ/diff: test-only extension; 0 lib/ lines changed; handwritten.
- Commands: above, exit 1 (falsifier red), ×2 identical.
- Transport failures: Grafana/PromEx nxdomain warnings — pre-existing, unrelated.
- Falsifiers: the red terminal-guard test IS the falsifier for the
  absent product guard; green journey legs falsify vacuity of the
  W947+W925 composition.
- BLOCKED: terminal-guard refusal (product guard absent, product fix
  needed by coordinator).
