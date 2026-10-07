# W290 — cross-dir consolidation run (chicago + sjira + ultracode + test/mix)

Subject: /Users/sac/xaas @ feat/playwright-surface (worktree state at run time, uncommitted lane state present)
Command: `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/xaas/chicago test/xaas/sjira test/xaas/ultracode test/mix`
Date: 2026-10-06

## Run 1 (foreground, tail-only capture)

```
Finished in 1136.5 seconds (72.8s async, 1063.7s sync)

Result: 1710/1716 passed (6/6 doctests, 1704/1710 tests), 1 skipped, 42 excluded
Failed: 6 tests
```

Visible failure 6: `Xaas.Ultracode.SemanticJiraE2ETest` (test/xaas/ultracode/semantic_jira_e2e_test.exs:115)
— `step_statuses == [{"compile","pass"},{"tests","fail"}]` got `[{"compile","fail"}]`.
Failures 1–5 scrolled past the tail window; identified via run 2.

## Run 2 (full-log rerun, same invocation)

```
Result: 1712/1716 passed (6/6 doctests, 1706/1710 tests), 1 skipped, 42 excluded
Failed: 4 tests
```

Failures:

1. `Xaas.Ultracode.SemanticDriveTest` — test/xaas/ultracode/semantic_drive_test.exs:113
   ("a prepared episode drives EP-A to ALIVE ...") — expected `{:ok, summary}`, got
   `{:refused, "standing" => "BUILD_BROKEN", "reason" => "fabric_court_build_broken"}`.
2. `Xaas.Ultracode.SemanticDriveTest` — test/xaas/ultracode/semantic_drive_test.exs:357
   ("a subject with no drift is REFUSED(no_delta) ...") — expected `REFUSED(no_delta)`,
   got `BUILD_BROKEN / fabric_court_build_broken` (same as #1).
3. `Xaas.Ultracode.MachineExperienceEpisodeTest` — test/xaas/ultracode/machine_experience_test.exs:1303
   (`assert attempt["standing"] == "ALIVE"` got nil).
4. `Xaas.Ultracode.MachineExperienceEpisodeTest` — test/xaas/ultracode/machine_experience_test.exs:1162
   — episode 1 got `UNKNOWN/exploration_budget_exhausted` instead of admitted MachineExperience;
   the single drive attempt was refused `REFUSED(reconcile_refused)` /
   `R_not_fed_back` ("promotion_refused evidence").

## Classification

- Run 1's failures #1–#4 = run 2's failures #1–#4 (same files/tests): deterministic, not
  contention. Common root cause: the fabric court's `mix format --check-formatted` step fails
  against the pinned ggen_igniter checkout —
  `/Users/sac/ggen_igniter/lib/ggen_igniter/semantic_jira/execute.ex` line 134 has a formatting
  drift (`{:ok, front} <- hop(...)` should be split across two lines per formatter), and the
  run's toolchain log shows `Error loading module 'Elixir.Hex': corrupt atom table`
  (OTP 27 mix 1.18.4 toolchain vs the pinned asdf OTP-28 toolchain). Both SemanticDrive
  failures are the direct BUILD_BROKEN verdict of that fixture-side format failure;
  both MachineExperience failures are the downstream cascade (drive attempt refused →
  promotion refused → episodes UNKNOWN / missing "ALIVE" standing).
  → Environment (GGEN_IGNITER_DIR content + PATH toolchain), not a xaas regression. No fix applied per lane scope.
- Run 1's extra failures #5–#6 (SemanticJiraE2ETest step_statuses, semantic_jira_e2e_test.exs:115
  and its sibling) did NOT recur in run 2 — they are the contention class
  (run 1 log shows "Waiting for lock on the build directory (held by process ...)" from
  concurrent lane build activity). Run 2 is the isolation rerun; both passed there.

## Standing

- 4 deterministic failures, all tracing to one fixture-environment cause (unformatted
  ggen_igniter execute.ex + toolchain mismatch in the drive sandbox). BLOCKED(env), not BUILD_BROKEN(xaas).
- 1712/1716 green in one invocation; no cross-dir interaction defects observed beyond the two
  run-1 contention flakes that passed on rerun.
- No fixes, no git operations performed.
