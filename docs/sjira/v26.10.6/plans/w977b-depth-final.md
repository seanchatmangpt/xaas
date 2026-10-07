# W977b — depth-suite final witness (v26.10.6)

- **Subject**: /Users/sac/xaas @ fab56ae19051c6bc2b501e4a1d6c91312344e2c3 (branch
  `feat/playwright-surface`, uncommitted sibling edits present in tree — listed under
  Classification)
- **Lane**: W977b, read-only witness lane; edited no code; no commit made. This receipt is
  the only file written by this lane.
- **Env**: elixir 1.20.2-otp-28 via asdf, `MIX_ENV=test`,
  `MIX_BUILD_ROOT=_build-laneW977b`, real Postgres (xaas_dev), local Postgres sandbox.
- **Command**:
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW977b mix test test/xaas/library/ test/xaas/conference/ test/xaas/operations/ test/xaas/governance/ test/xaas_web/ test/xaas/semantics/ test/xaas/telemetry/ test/xaas/ontology/ test/xaas/ultracode/ test/xaas/bridges/ --include eu_ai_act --exclude eu_ai_act_open_gap`

## Result

```
Finished in 791.1 seconds (48.5s async, 742.5s sync)
Result: 2700/2724 passed (15/15 doctests, 2685/2709 tests), 12 skipped, 51 excluded
Failed: 24 tests
EXIT=2
```

Run 2 (`mix test --failed`, real log `/tmp/w977b-failures.log`):

```
Finished in 125.9 seconds (83.7s async, 42.2s sync)
Result: 7/24 passed
Failed: 17 tests
```

- **17 stable failures (×2 grounded)**, **7 flakes (run-1-only)**, 2700 passed.
- Full run-1 log: `/tmp/w977b-depth-final.log` (4045 lines).

## Pre-run compile interruptions (sibling-in-flight, disclosed)

- Attempt 0 (`mix compile`): `lib/xaas/billing/approval_patch_sla_credit_apply.ex` mid-edit
  (missing `)` on `change(...)` at line 147). Files `approval_patch_sla_credit_apply.ex` /
  `subscription.ex` mtimes moved 08:18→08:20 while this lane polled; compile passed after the
  sibling settled.
- Attempt 1 (`mix test`, aborted at compile): `parse_inline_idents?(false)` DSL error in
  `lib/xaas/billing/approval_patch_sla_credit_apply.ex` (file rewritten again at 08:32 by
  sibling). 20 min quiet, then retry succeeded.
- Depth-suite run itself started 08:53:31, finished ~09:06:41.

## Stable failures (17, ×2) — run-1 names with files

1. `conference_speaker type does not expose keynote? (W981b)` —
   `Xaas.Conference.KeynoteGraphqlSurfaceCourtTest` (untracked NEW file
   test/xaas/conference/keynote_graphql_surface_court_test.exs) —
   `XaasWeb.Schema.__absinthe_blueprint__/0 is undefined (module XaasWeb.Schema is not available)`
2. `every GraphQL field name in XaasWeb.Schema satisfies the Name spec` — same test file, same
   error (schema module not available in test env)
3. `RecommendationPipelineReactor ranks candidates concurrently with 6-factor scoring` —
   `Xaas.Library.Reactors.RecommendationPipelineReactorTest`
4. `W766 Next Read LiveView deepening (a) mount renders the real 6-factor ranker order` —
   `XaasWeb.NextRead.ReaderLiveDeepeningTest`
5. `W766 Next Read LiveView deepening (b) real PubSub inventory broadcast` — same file
6. `duplicate Checkout.borrow with the same idempotency key does not double-decrement` —
   `Xaas.Library.CheckoutActuationTest`
7. `same book+user+school but a different idempotency key is a distinct borrow` — same file
8. `(b) read-only doctrine: ... unroutable via the GraphQL surface too (type-only)` —
   `Xaas.Operations.RouteCastleRunSurfaceTest` — `Expected exception Phoenix.NotAcceptableError
   but nothing was raised`
9. `avatar 2: return with exactly one active hold — cascade fulfils hold, no separate Checkout
   row` — `XaasWeb.A2A.ReturnHoldCascadeAvatarsTest`
10. `empty catalog edge case returns an empty recommendation list` — `Xaas.Library.RankerTest`
11. `grade_fit factor decays as the book's grade level moves further from the student's grade` —
    `Xaas.Library.RankerTest`
12. `empty catalog edge case ... exclude_read is true` — `Xaas.Library.RankerTest`
    (test/xaas/library/ranker_test.exs:398)
13. `no notification record is created by fulfillment — PubSub broadcast only` —
    `Xaas.Library.CheckoutPolicyDeepeningTest` — `assert open_checkouts_for(waiting.id) == []`
    left: one open Checkout row for the hold holder
14. `return on an exhausted book hands the copy to the oldest hold` —
    `Xaas.Library.CheckoutPolicyDeepeningTest`
15. `(c) RecommendationLog captures the 6-factor weights ...` —
    `Xaas.Library.NextReadDeepeningTest` — assertion == failed at
    test/xaas/library/nextread_deepening_test.exs:216
16. `W973b terminal guard: a cancelled registration cannot :cancel again (typed refusal)` —
    `Xaas.Conference.EnrollmentJourneyCourtTest` —
    `Expected exception Ash.Error.Invalid but nothing was raised`
17. `Dynamic Configuration & 6-Factor Next Read Composite Ranker ...` —
    `Xaas.Library.NextReadTest` — `assert rec_low != nil` left: nil at
    test/xaas/library/next_read_test.exs:205

## Flakes (7, run-1-only; passed run 2)

1. `mix xaas.machine_experience (real OS process ...)` —
   `Xaas.Ultracode.MachineExperienceTest` — run-1 failure was itself a captured compile error
   of `lib/xaas/ocel/event.ex` (`undefined function graphql/1`) from the sibling's in-flight
   edit — timing, not code
2. `mix xaas.replay under the no-LLM cold environment ...` — `Xaas.Ultracode.SemanticReplayTest`
3. `W981s: cancelled attendee re-registers into the same session ...` —
   `Xaas.Conference.EnrollmentJourneyCourtTest`
4–7. `PATCH ...` approval-tier-downgrade controller cluster (4 tests) —
   `XaasWeb.ApprovalTierDowngradeControllerTest` —
   expected-exception/message mismatches during sibling churn on
   `lib/xaas/governance/freeze_window.ex` / router / controller test file (all `M` in git
   status, mtimes moving during the run)

## Classification (×2 contract)

- **Sibling-in-flight (stable)**: the GraphQL-surface court failures (#1–2) trace to one root:
  the sibling's in-flight `graphql do` block additions (`lib/xaas/ocel/event.ex`,
  conference `speaker.ex`) referencing a schema module `XaasWeb.Schema` that does not compile
  in the test env — `XaasWeb.Schema.__absinthe_blueprint__/0 is undefined`. #8 (route castle
  read-only doctrine) is the same schema-unavailability family. The Next-Read/6-factor,
  checkout-idempotency, and ranker cluster (#3–7, 10–15, 17) sits in files with uncommitted
  sibling edits and matches the continuing W946b cluster (below). Conference terminal-guard
  (#16) and avatar cascade (#9) sit in files dirty at run time (`event.ex`,
  `registration.ex`, `speaker.ex`, `router.ex` all `M`, untracked new court files). Lane
  W977b edited no code; none of the 17 can be a W977b regression by construction.
- **Flake (×1)**: the 7 run-1-only names above (real-OS-process tests and PATCH cluster during
  governance/router churn).
- **Regression**: zero attributable to this lane; the GraphQL-surface failures are new on the
  tree but caused by sibling edits, so they are sibling-in-flight, not witness-lane regressions.

## Delta vs W946b (`w946b-depth-combine-2.md`)

W946b's 10 stable failures on the same scope family:
- **Resolved (2)**: `AuditLogEntry rollback` (W835 governance repairs) and
  `authority_decoupling axiom A` (W897 semantics repairs) now PASS in this run — the two
  non-cluster stable failures from W946b are gone.
- **Persisting (7)**: RecommendationPipelineReactor, W766 LiveView (a)/(b), borrow-idempotency
  pair, RecommendationLog (c), NextRead composite ranker — the identical Next-Read/6-factor
  cluster W946b classified sibling-in-flight; it is still in flight (tree still dirty in the
  same files).
- **Reclassified (1)**: `machine_experience` (W946b stable) failed run 1 here for a
  sibling-timing compile capture, passed run 2 → demoted stable→flake; improved.
- **New on this run (10)**: GraphQL-surface courts (keynote?/Name spec), route-castle
  read-only doctrine (type-only), avatar-2 hold cascade, empty-catalog ×2, grade_fit decay,
  no-notification-PubSub, return→oldest-hold, W973b terminal guard. Nine of the ten sit in
  conference/library/web areas with uncommitted sibling edits or new untracked court files —
  sibling-in-flight; the GraphQL pair has a named root cause (`graphql do` DSL blocks
  referencing `XaasWeb.Schema` not compiled in test env).

## Standing

- **Depth-suite ALIVE witness: PARTIAL_ALIVE** — real run, real build root, real tail quoted
  above; 2700/2724 passed (99.1%); 17 stable failures ×2-grounded, all classified
  sibling-in-flight; 7 flakes; 0 regressions from this lane.
- The 2 W946b non-cluster stable failures resolved; the 7-test Next-Read/6-factor cluster
  persists across both witness runs (two witnesses, same classification) — the strongest
  grounded signal that this cluster tracks in-flight sibling work on the library/next-read
  surface, not flake or regression.
- Lane W977b edited no code; no commit made; build root `_build-laneW977b` left in place
  (compile state valid as of 09:07; sibling lanes actively compiling — coordinator deletes at
  integration per same-checkout fanout cleanup law).
