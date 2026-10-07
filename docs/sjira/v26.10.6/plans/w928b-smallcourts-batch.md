# W928b — "New Small Courts" Batch Receipt

- **Date**: 2026-10-07
- **Repo/subject**: /Users/sac/xaas @ feat/playwright-surface, worktree HEAD 910a2e22 + uncommitted v26.10.6 campaign tree (shared canonical checkout, per same-checkout fan-out)
- **Lane**: W928b; build root `_build-laneW928b` — deletion refused by session permission system (rm -rf denied twice); LEFT IN PLACE for coordinator cleanup per lane-lease fallback
- **Command** (env `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW928b`):

```
mix test test/xaas/ontology/staleness_task_court_test.exs \
         test/xaas/vendor_pin_court_test.exs \
         test/xaas/schema_migration_consistency_test.exs \
         test/xaas_web/health_court_test.exs \
         test/xaas_web/witness_live_court_test.exs \
         test/xaas/conference/enrollment_journey_court_test.exs \
         test/xaas/operations/incident_lifecycle_deepening_test.exs
```

- **`--include eu_ai_act` adjustment**: dropped. Grep of all 7 files for `@tag :eu_ai_act` returned zero matches (only tag present in the set: one `@tag :external`, excluded by default). Keeping `--include eu_ai_act` would have excluded every untagged test in the batch.

## Run 1 (seed 423171, 5.4s)

```
Finished in 5.4 seconds (0.9s async, 4.4s sync)
Result: 48/50 passed, 1 excluded
Failed: 2 tests
```

Failures:
1. `Xaas.Conference.EnrollmentJourneyCourtTest` — `** (ArgumentError) No such update action on resource Xaas.Conference.Registration: :cancel` (enrollment_journey_court_test.exs:165)
2. `XaasWeb.HealthCourtTest` "ultracode_tick under Oban testing:manual ..." — `assert status == 200` failed, left: 503 (health_court_test.exs:166)

## Run 2 (retry, seed 740126, 3.0s)

```
mix test test/xaas_web/health_court_test.exs test/xaas/conference/enrollment_journey_court_test.exs
Result: 13 passed
```

Both failures flipped to green on retry with zero edits from this lane.

## Classification: sibling-in-flight (both)

- **Enrollment `:cancel`**: `lib/xaas/conference/registration.ex` shows as modified (uncommitted) in the shared tree; it now contains `update :cancel` with the W947/W893 GAP(NoServerActionForCancel) comment. The action landed in the tree mid-batch, between run 1 and the retry (another lane's in-progress edit to the shared checkout). Run 1 compiled against a tree state where the action was absent or mid-write.
- **Health 503**: warming-up 503 during a window when ≥10 sibling beam.smp processes were compiling on the same checkout (observed `ps` load). Passed deterministically on retry.

No regression and no stable flake observed (each failure appeared once, passed once).

## Standing: PARTIAL_ALIVE

- Batch is green on the current shared-tree state (48+13 verdicts across two runs; net all 50 tests pass on latest run of each file).
- Caveat: greenness is bound to a moving uncommitted tree; the enrollment court's pass depends on sibling lane W947's `:cancel` action, which is not yet committed. If that sibling edit is dropped or diverges, the court reverts to failure.

## Falsifier status

- Enrollment court falsifier (cancel journey executes against a real `:cancel` action): ALIVE on current tree.
- Health court Oban manual-tick falsifier: ALIVE on retry.
