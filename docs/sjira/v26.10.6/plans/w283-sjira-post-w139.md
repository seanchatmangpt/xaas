# W283 — sjira dir receipt, post-W139 origin-authority changes + SJ-001 fixture regen

- Lane: W283 integration, v26.10.6 convergence, repo /Users/sac/xaas (canonical checkout).
- Scope: post-W139 verification only. W139 (see `w139-e4-adjudication.md`) landed
  `origin_authority` as a required field of `admit_work_order/1` from the ggen_igniter
  kernel head (AC-04 law), plus the SJ-001 fixture regeneration. W283 ran the sjira test
  directory against that state. No fixes, no git transitions, no lib edits.

## Command (exact)

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH \
  GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test \
  mix test test/xaas/sjira --exclude external --exclude subprocess 2>&1 | tail -5
```

## Result (verbatim)

```
Running ExUnit with seed: 53405, max_cases: 32
Excluding tags: [:external, :subprocess, :stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external_llm, :property, :castle_kernel]

...........................................................................................................
Finished in 7.7 seconds (5.4s async, 2.2s sync)

Result: 107 passed
```

## Counts and classification

- **107 passed, 0 failed, 0 invalid, 0 skipped** (rerun grep for `skipped|excluded` test
  lines: 0 matches — no typed skips fired in this exclusion set; the
  `:external`/`:subprocess` exclusions are config-level, not per-test skip records).
- Note: the "typed skips expected" hypothesis did not materialize as per-test skip lines —
  the only skips are the config-level tag exclusions shown above.
- W139's SJ-001 E2E is `:subprocess`-tagged and excluded here by design; it is NOT covered
  by this receipt (its own run is a separate work order).
- Files covered: `ard_court_test.exs`, `atlassian_test.exs`,
  `atlassian_transport_test.exs`, `engineer_workflow_test.exs`,
  `governance_obligation_test.exs`, `governance_route_test.exs`, `successor_test.exs`,
  `yield_test.exs` (8 files, `test/xaas/sjira/`).
- Env noise (pre-existing, unrelated to sjira assertions): PromEx/Grafana `:nxdomain`
  dashboard-upload warnings at boot (no local Grafana); `[os_mon]` shutdown notices.
  Zero assertion-level failures. Seed 53405.

## Classification of failures

None. 0 failures to classify.

## Standing

- sjira dir under the post-W139 origin_authority law + regenerated SJ-001 fixtures:
  **ALIVE** (observed execution, exact command, exit 0, on the current working tree of
  `feat/playwright-surface`).
- Out of scope / not witnessed: SJ-001 `:subprocess` E2E; anything outside `test/xaas/sjira/`.
