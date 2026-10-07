# W273 — test/sjira root-dir receipt (post-format, v26.10.6 convergence)

- Repo: /Users/sac/xaas
- Date: 2026-10-06
- Subject: `test/sjira/v26_9_23_goal_test.exs` (formatted in W237, vacuity-fixed in W210)
- Lane: W273 integration, receipt only — no fixes, no git operations.

## Command

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH \
  GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/sjira
```

## Result (verbatim)

```
Running ExUnit with seed: 898166, max_cases: 32
Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel]

Finished in 63.6 seconds (0.00s async, 63.6s sync)

Result: 33 passed, 4 skipped
```

Exit summary: **33 passed, 0 failed, 4 skipped** (63.6 s, sync).

## Failure classification

- Failures: none.
- Skips: 4 total, all `skip: @compile_prose_skip` typed skips in
  `test/sjira/v26_9_23_goal_test.exs` (lines 434, 500, 841, 861) — expected per
  W155/W195/W238. No unexpected skips, no unexpected failures.

## Ambient noise (non-test, pre-existing)

PromEx/Grafana dashboard uploader warnings (`nxdomain` to Grafana, `:unkown`)
during boot; no test impact.

Standing: root-dir `test/sjira` suite ALIVE under the pinned toolchain
(asdf elixir) with GGEN_IGNITER_DIR bound; counts match the post-W210/W237
expectation of only typed compile_prose skips.
