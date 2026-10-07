# W982e — Gate-5 ALIVE Falsifier Rerun (quiescent-tree attempt)

Standing: **PARTIAL_ALIVE** — full gate-5 depth suite executed for real on a
fresh lane build root; 908/920 passed, 12 failures, 7 flake-class (passed on
failing-file rerun), 5 persistent-under-current-tree. Not ALIVE (failures
present). W972's deterministic W973b pair: **both still fail** — SPEC-31 did
not close the W973b terminal guard (guard is still not implemented on the
current tree; a sibling is actively iterating `registration.ex` W981s/W983a).

## Exact subject

- Repo: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `6f235905`
  (dirty tree, sibling lanes in flight: W981s/W983a registration work, new
  untracked stress/keynote test files, approval-controller files in flight).
- Toolchain: asdf elixir 1.20.2-otp-28, MIX_ENV=test,
  `MIX_BUILD_ROOT=_build-laneW982e`.
- Note: denominator moved 908→920 vs W972 — siblings added tests mid-flight
  (checkout-hold-lifecycle stress, keynote GraphQL court, W969e/W981s journey
  tests, approval SLA-credit controllers). Not a like-for-like numerator.

## Command (run 3, full gate-5 suite)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982e \
  mix test test/xaas/library/ test/xaas/conference/ test/xaas/operations/ \
  test/xaas/governance/ test/xaas_web/ \
  --include eu_ai_act --exclude eu_ai_act_open_gap
```

Exact tail (`/tmp/w982e-gate5-run3.log`):

```
Finished in 25.3 seconds (3.0s async, 22.2s sync)
Result: 908/920 passed, 11 excluded
Failed: 12 tests
EXIT=2
```

Failing-file rerun (`/tmp/w982e-gate5-rerun.log`), 7 files / 40 tests:

```
Result: 35/40 passed
Failed: 5 tests
EXIT=2
```

## Compile-abort transport (2 sibling-in-flight blockers, resolved by waiting)

- Run 1: `EXIT=1` — sibling's untracked
  `test/xaas/library/checkout_hold_lifecycle_stress_test.exs` (pipe-into-alias
  ArgumentError, line ~306). File was iterating (mtime moved during my wait);
  settled in ~10 min. Log: `/tmp/w982e-gate5-run1.log`.
- Run 2: `EXIT=1` — sibling's untracked
  `test/xaas/conference/keynote_graphql_surface_court_test.exs`
  (TokenMissingError, unclosed `defmodule`). Settled ~10 min later. Log:
  `/tmp/w982e-gate5-run2.log`. No BLOCKED(compile,other-lane) issued — both
  settled within the wait window.

## Run-3 failures (12) — classification

Flake-class (failed run 3, passed on failing-file rerun) — 7:

1. `XaasWeb.ApprovalPatchSlaCreditApplyControllerTest` "PATCH rejects
   approving a request whose org_id does NOT match the actor's asserted org"
2. `XaasWeb.ApprovalPatchSlaCreditApplyControllerTest` "POST rejects creating
   a request whose org_id does NOT match..."
3. `Xaas.Library.CheckoutHoldLifecycleStressTest` "concurrent double :fulfill
   over real Postgres: exactly one success, loser refused typed" (sibling's
   brand-new stress file)
4. `Xaas.Conference.EnrollmentJourneyCourtTest` "W969e legal walk..."
5. `Xaas.Conference.EnrollmentJourneyCourtTest` "W981s: cancelled attendee
   re-registers... active duplicate still refused" — sibling mid-iteration on
   `registration.ex` (identity removed, `EnforceActiveRegistrationIdentity`
   added during this run)
6. `XaasWeb.ApprovalSlaCreditApplyControllerTest` "PATCH rejects approving..."
7. `XaasWeb.ApprovalSlaCreditApplyControllerTest` "POST rejects creating..."

Persistent (failed both runs) — 5:

1. `Xaas.Operations.RouteCastleRunSurfaceTest` "(b) read-only doctrine: ...
   still unroutable via the GraphQL surface too (type-only)" —
   `route_castle_run_surface_test.exs:195`, expected
   `Phoenix.NotAcceptableError`, nothing raised. Same as W972 deterministic #9.
2. `XaasWeb.A2A.ReturnHoldCascadeAvatarsTest` "avatar 2: ... sole active hold
   is fulfilled by the cascade" — W972 flake #4 no longer flakes; it failed
   both of my runs. Reclassified: **persistent**.
3. `Xaas.Library.CheckoutPolicyDeepeningTest` "no notification record is
   created by fulfillment -- PubSub broadcast only"
   (`checkout_policy_deepening_test.exs:230`, `open_checkouts_for(waiting.id)`
   non-empty — checkout row exists after fulfillment+return where test expects
   none). W972 flake #7 now persistent.
4. `Xaas.Library.CheckoutPolicyDeepeningTest` "return on an exhausted book
   hands the copy to the oldest hold" (`:172`, same assertion shape). W972
   flake #8 now persistent.
5. `Xaas.Conference.EnrollmentJourneyCourtTest` "W973b terminal guard: a
   cancelled registration cannot :cancel again (typed refusal)"
   (`enrollment_journey_court_test.exs:439`, expected `Ash.Error.Invalid`,
   nothing raised). Same as W972 deterministic #10. Inspected the working-tree
   diff: `registration.ex` has W981s/W983a changes (identity removed,
   `EnforceActiveRegistrationIdentity` on :create) but **no :cancel terminal
   guard exists** — the test asserts behavior no code implements yet.

## W972 flake-class reproduction check

| W972 flake | reproduced here? |
|---|---|
| #1 GraphqlHttpSurface shadowing pin | no — passed |
| #2 GraphqlHttpSurface wired-domain rows | no — passed |
| #3 W973b journey re-register slot | no (that test passed; the journey file failed on different, newer tests W969e/W981s) |
| #4 avatar 2 cascade | YES — failed both runs, reclassified persistent |
| #5 W968c previous_status | no — passed |
| #6 401/403 matrix | no — 401/403 matrix passed; instead 4 sibling-in-flight approval/org-mismatch tests flaked (ApprovalPatch/ApprovalSlaCredit ×4, new since W972) |
| #7 PubSub-only | YES — failed both runs, reclassified persistent |
| #8 exhausted-hold | YES — failed both runs, reclassified persistent |

## Counts

| run | scope | passed | failed | excluded |
|---|---|---|---|---|
| run 3 (full gate-5) | 920 tests | 908 | 12 | 11 |
| rerun (7 files, 40 tests) | 40 | 35 | 5 | — |

## Standing & falsifier

- Gate-5 depth suite: **PARTIAL_ALIVE** vs W972's 898/908 → 908/920 (same
  pass count, +12 new tests, +2 net failures; 7 of 12 flake-class on
  sibling-in-flight surfaces).
- Residual list (5 persistent): route-castle type-only GraphQL routing gap;
  avatar-2 hold cascade; 2× checkout-policy hold-fulfillment row-leak; W973b
  :cancel terminal guard (unimplemented).
- Falsifier for ALIVE unchanged from W972: gate-5 rerun with 0 failures on a
  quiescent tree. The W973b terminal guard and route-castle type-only tests
  assert behavior with no implementing code on the current tree — they remain
  new-assertion-mid-flight, not repairs regressing.
- Lane build root `_build-laneW982e` NOT deleted — `rm -rf` denied in lane;
  coordinator cleanup required per same-checkout-fanout cleanup law.
- Logs: `/tmp/w982e-gate5-run1.log`, `/tmp/w982e-gate5-run2.log`,
  `/tmp/w982e-gate5-run3.log`, `/tmp/w982e-gate5-rerun.log`.
