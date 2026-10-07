# W972 — Gate 5 Depth-Suite Fold (post-repair-batch witness)

Standing: **PARTIAL_ALIVE** — full gate-5 depth suite executed for real; 898/908
passed; 10 failures on the combined pass, 0 attributable to any W897/W900/W902/
W925/W935/W865/W925b repair. All 20 of w929's failures are resolved (0 overlap).
The 10 current failures sit on W973b/W968/W975b sibling-in-flight surfaces, not
on repaired surfaces. Not ALIVE (failures present); not BLOCKED.

## Exact subject

- Repo: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `6f235905`
  (dirty tree, many sibling lanes in flight: W951/W959/W946/W974/W969b/W973b/W975b).
- Toolchain: asdf elixir 1.20.2-otp-28, MIX_ENV=test,
  `MIX_BUILD_ROOT=_build-laneW972` (left in place; `rm -rf` denied in lane —
  coordinator cleanup required per same-checkout-fanout cleanup law).

## Command (run 2, full gate-5 suite)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW972 \
  mix test test/xaas/library/ test/xaas/conference/ test/xaas/operations/ \
  test/xaas/governance/ test/xaas_web/ \
  --include eu_ai_act --exclude eu_ai_act_open_gap
```

Exact tail (`/tmp/w972-gate5-run2.log`):

```
Finished in 45.6 seconds (7.7s async, 37.8s sync)
Result: 898/908 passed, 11 excluded
Failed: 10 tests
EXIT=2
```

Rerun of the 7 failing files (`/tmp/w972-gate5-rerun3.log`):

```
Finished in 2.7 seconds (0.00s async, 2.7s sync)
Result: 59/61 passed
Failed: 2 tests
EXIT=2
```

## Run-1 note (disclosed, not counted)

First full attempt aborted at compile (`EXIT=1`): sibling lane W969b had
`freeze_window_active_gate_test.exs` on disk calling `_approved_override!`
(undefined). Settled after ~6 min; run 2 then compiled clean. A later rerun of
failing files aborted on a second sibling compile break (W975b `keynote?`
GraphQL field in `lib/xaas/conference/speaker.ex`); settled after the sibling's
`public?: false` fix landed. Both are sibling-in-flight transport, not suite
failures.

## Run-2 failures (10) — classification

Flake-class (failed run 2, passed on failing-file rerun) — 8:

1. `XaasWeb.GraphqlHttpSurfaceTest` "registered before the /api catch-all
   forward (shadowing pin)" — sibling route surface in flight.
2. `XaasWeb.GraphqlHttpSurfaceTest` "a wired-domain query returns real rows
   (libraryBooks)".
3. `Xaas.Conference.EnrollmentJourneyCourtTest` "W973b journey: register →
   cancel → re-register → cancel → re-register (slot released repeatedly)" —
   W973b surface, sibling iterating.
4. `XaasWeb.A2A.ReturnHoldCascadeAvatarsTest` "avatar 2 ... sole active hold is
   fulfilled by the cascade".
5. `Xaas.Operations.CapabilityLivenessDeepeningTest` "W968c: previous_status is
   written by :ingest on overwrite and not forgeable by callers" — W968 surface.
6. `Xaas.Governance.MultitenantApprovalDeepeningTest` "(e) 401/403 matrix".
7. `Xaas.Library.CheckoutPolicyDeepeningTest` "no notification record is created
   by fulfillment -- PubSub broadcast only".
8. `Xaas.Library.CheckoutPolicyDeepeningTest` "return on an exhausted book hands
   the copy to the oldest hold (re-decrementing inventory)".

Deterministic-under-current-tree (failed both runs) — 2:

9. `Xaas.Operations.RouteCastleRunSurfaceTest` "(b) read-only doctrine: ...
   still unroutable via the GraphQL surface too (type-only)" — expected
   `Phoenix.NotAcceptableError`, nothing raised
   (`test/xaas/operations/route_castle_run_surface_test.exs:195`). Sibling lane
   W973b-named surface (test file, not repaired surface).
10. `Xaas.Conference.EnrollmentJourneyCourtTest` "W973b terminal guard: a
    cancelled registration cannot :cancel again (typed refusal)" — expected
    `Ash.Error.Invalid`, nothing raised
    (`test/xaas/conference/enrollment_journey_court_test.exs:359`). Explicitly
    W973b-labeled test; the guard the test asserts does not raise yet.

Zero regression-class failures: none of the 10 touches a W897/W900/W902/W925/
W935/W865/W925b-repaired test.

## Delta vs w929 (prior witness)

w929 (HEAD `a0723bf6`): 20 failures across the combined depth suite
(4022/4042 passed); within the gate-5 directories: 3× AuditExportTokenController
404s, AuditLogEntry rollback, RecommendationPipelineReactor 6-factor, Ranker
empty-catalog ×2, NextReadDeepening scored-length, NextRead ReaderLive ×2,
GymactSurface ×4, HealthController/HealthCourt warming_up ×2.

w972 (HEAD `6f235905`): 10 failures (898/908), **0 overlap** with the w929 set
— every w929 failure in these directories is resolved by the repair batches.
Net delta: **−20 resolved, +10 new**, and the new 10 are concentrated on
W973b/W968 sibling-in-flight surfaces that did not exist as assertions at w929
time (both deterministic failures are tests named "W973b..."), i.e. new
assertions landing mid-flight, not repairs regressing.

## Counts

| run | scope | passed | failed | excluded |
|---|---|---|---|---|
| run 2 (full gate-5) | 908 tests | 898 | 10 | 11 |
| rerun (7 files, 61 tests) | 61 | 59 | 2 | — |

## Standing & falsifier

- Gate-5 depth suite: **PARTIAL_ALIVE**. Repaired surfaces hold; the residual
  failure set is sibling-in-flight (W973b terminal guard + route-castle
  read-only type-only test deterministic; 8 flake-class).
- Falsifier for ALIVE: a gate-5 rerun on a quiescent tree with W973b/W968
  landed, showing 0 failures.
- Logs preserved: `/tmp/w972-gate5-run2.log`, `/tmp/w972-gate5-rerun3.log`
  (earlier aborted attempts: `/tmp/w972-gate5.log`, `/tmp/w972-gate5-rerun.log`,
  `/tmp/w972-gate5-rerun2.log`).
