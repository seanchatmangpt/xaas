# W128 — oracle courts final rerun (receipt)

*Backfilled by coordinator from lane completion report.* Subject: /Users/sac/xaas @ feat/playwright-surface, 2026-10-06.

## Result
`mix test test/sjira/v26_9_23_goal_test.exs test/mix/tasks/xaas_stop_court_test.exs` (GGEN_IGNITER_DIR set):
- Run 1: 52/56 passed, 4 failed. Run 2: 51/56 (one flaky GC23-12 registry assertion on shared tmp/receipt state).
- All 4 stable failures identical: exit 75, `UNKNOWN: ... no mix semantic_jira.compile_prose in /Users/sac/ggen_igniter` (goal_test:811/474/827, stop_court:414).

## Key findings
1. W107's falsifier falsified: the residual is NOT fixable by sibling `mix compile` — `semantic_jira.compile_prose.ex` is absent from ggen_igniter's SOURCE at 7dbcdb3 (retired dc27242). Classification: BLOCKED(machinery_absent_at_sibling_source) — cross-repo V23-C deliverable → OS-9.
2. Committed corpus proof: `docs/sjira/v26.9.23/receipts/STOP-GC-26.9.23.json` — corpus 13/13 ALIVE at machinery-bearing SHA cb399128.

## Post-W155/W195/W208 state
Machinery-dependent tests typed-skipped (re-arm at machinery-bearing SHAs); final trio confirmation W203: 51 passed / 5 typed-skips / 0 failed.
