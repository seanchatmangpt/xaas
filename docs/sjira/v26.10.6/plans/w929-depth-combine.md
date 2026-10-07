# W929 — Combined Depth-Surface Suite Witness

Standing: **PARTIAL_ALIVE** — combined run executed for real; 20 failures on first
combined pass, 9 deterministic-under-current-tree, 11 non-repeating (flake-class).
Not ALIVE (failures present); not BLOCKED (suite runs end-to-end).

## Exact subject

- Repo: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6`
  (dirty tree, many in-flight sibling lanes).
- Toolchain: asdf elixir 1.20.2-otp-28, MIX_ENV=test,
  `MIX_BUILD_ROOT=_build-laneW929` (left in place for coordinator; `rm` denied in lane).

## Command (run 1)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW929 \
  mix test test/xaas/semantics/ test/eu_ai_act/ test/xaas_web/ test/xaas/library/ \
  test/xaas/operations/ test/xaas/governance/ test/xaas/ultracode/ \
  test/xaas/bridges/ test/xaas/telemetry/ test/xaas/ontology/ \
  --include eu_ai_act --exclude eu_ai_act_open_gap
```

Exact tail (run 1, `/tmp/w929-depth-run1.log`):

```
Finished in 615.3 seconds (63.1s async, 552.2s sync)
Result: 4022/4042 passed (15/15 doctests, 4007/4027 tests), 12 skipped, 52 excluded
Failed: 20 tests
EXIT=2
```

Rerun of the 12 failing files only (`/tmp/w929-depth-rerun.log`):

```
Finished in 143.8 seconds (140.0s async, 3.7s sync)
Result: 80/89 passed, 4 skipped
Failed: 9 tests
EXIT=2
```

## Failure classification (run 1 → rerun)

Deterministic (failed both runs) — 9:

1. `Xaas.Semantics.AuthorityDecouplingTest` "axiom A: gate outcome depends only on
   opts, never on candidate content" — expected
   `{:error, {:reactor_failed, %Reactor.Error.Invalid{}}}`, got
   `{:error, :subject_id_required}`. Error-shape drift. Owning lane: W512
   (`w512-gpai-decoupling.md`).
2. `Xaas.Governance.AuditLogEntryTest` "a real forced AuditLogEntry write failure
   rolls back approved_by too -- never approved-but-unaudited". Owning lane: W728
   (`w728-audit-log-deepening.md`).
3. `Xaas.Library.Reactors.RecommendationPipelineReactorTest` "ranks candidates
   concurrently with 6-factor scoring" — NextRead 6-factor surface, W742/W766
   lane family (`w742-nextread-deepening.md`, `w766-nextread-live-deepening.md`).
4-6. `XaasWeb.AuditExportTokenControllerTest` × 3 (PATCH revoke endpoints return
   **404 no_route_found** instead of 200/403/400). An untracked sibling file
   `test/xaas_web/audit_export_token_route_collision_court_test.exs` exists in the
   tree — a route-collision court lane is in-flight on exactly this surface.
   Corroborating: run 1 captured a compile error in
   `lib/xaas/governance/audit_export_token.ex:121` (`use_count + 1` →
   `Enumerable not implemented for Ash.Query.Call`) inside a spawned `mix`
   subprocess — a mid-flight edit caught mid-compile.
7. `Xaas.Library.RankerTest` "empty catalog edge case ... no candidate books".
8. `Xaas.Library.RankerTest` "empty catalog ... every catalog book already checked
   out and exclude_read is true" (exclude_read not honored).
9. `Xaas.Library.NextReadDeepeningTest` "(c) RecommendationLog ... weights and
   ranked_items match the real inputs" — `length(scored) == 3` got `10`; ranker
   returns 10 where the test crafts 3 candidates → ranker surface in flight
   (W742/W766 NextRead family).

Flake-class (failed run 1, passed on rerun) — 11:

- `Xaas.Ultracode.MachineExperienceTest` — subprocess compile raced an in-flight
  sibling edit of `audit_export_token.ex`; passed once the edit settled.
- `Xaas.Library.NextReadTest` (6-factor ranker scoring test).
- `XaasWeb.HealthControllerTest` + `XaasWeb.HealthCourtTest` `ultracode_tick`
  warming_up pair — timing.
- `XaasWeb.NextRead.ReaderLiveDeepeningTest` (a) and (b).
- `Xaas.Operations.GymactSurfaceDeepeningTest` × 4 — `Ash.Query.filter/2`
  undefined (missing `require Ash.Query`); the file is modified in-tree by
  sibling lane W928 (`w928-gymact-hygiene.md`); passed on rerun after the
  sibling's edit settled.

## Counts

| run | tests | passed | failed | skipped | excluded |
|---|---|---|---|---|---|
| run 1 (combined) | 4027 | 4007 | 20 | 12 | 52 |
| rerun (12 files) | 89 | 80 | 9 | 4 | — |

## Standing & falsifier

- Combined depth suite: **PARTIAL_ALIVE**. 4022/4042 passed; 9 deterministic
  failures, all clustered in sibling-in-flight surfaces (W512 semantics gate
  error-shape, W728 audit log, W742/W766 NextRead ranker, audit-export-token
  route-collision lane) — none attributable to the W929 run itself, which only
  ran tests.
- Falsifier for full ALIVE: a combined rerun on a quiescent tree with 0 failures.
- Logs preserved at `/tmp/w929-depth-run1.log` and `/tmp/w929-depth-rerun.log`.
