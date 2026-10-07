# W457 — autofde dir slice, final tree

Repo: /Users/sac/xaas @ feat/playwright-surface (canonical checkout). Lane W457.

## Locate

`grep -rl autofde test/xaas test/xaas_web` → 12 files (not just the 3 W372 ran):
- test/xaas/autofde/status_parser_test.exs
- test/xaas_web/live/autofde_lab/status_live_test.exs
- test/xaas/operations/autofde_planner_cross_product_test.exs
- test/xaas/operations/autofde_planner_candidate_test.exs
- test/xaas/system_authority_service_scope_test.exs
- test/xaas/system_authority_followup_chicago_test.exs
- test/xaas/sa2a/bridge_test.exs
- test/xaas/sa2a/bridge_authority_subprocess_chicago_test.exs
- test/xaas/sa2a/execute_test.exs
- test/xaas/sjira/yield_test.exs
- test/xaas/ultracode/target_suites_test.exs
- test/xaas/ultracode/sj_program_registry_test.exs

## Command

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW457 \
  mix test <all 12 paths above>
```

## Real tail

```
............................................******************.
Finished in 4.3 seconds (1.0s async, 3.3s sync)

Result: 61 passed, 18 skipped, 4 excluded
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

[exited with code 0]
```

(Exit 0. Compile-time warnings only: pre-existing type warning in
system_authority_service_scope_test.exs:96 referencing `:ultracode_reactor`/
`:webhook_dispatcher` — no failures.)

## Verdict

**autofde slice green-at-final-tree**: 61 passed, 18 skipped, 4 excluded, 0 failed,
exit 0 across all 12 autofde-referencing files. Skips are the typed skips of the
two `requires_cnv_deploy`-tagged planner files
(`operations/autofde_planner_cross_product_test.exs`,
`operations/autofde_planner_candidate_test.exs`) — expected per w412, not failures.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW457` — **DENIED** by permission system
(437 MB dir remains on disk at `/Users/sac/xaas/_build-laneW457`). Coordinator
should remove it at integration per cleanup law.
