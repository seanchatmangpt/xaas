# W280 — Async env isolation (INTERNAL_API_TOKEN), v26.10.6 convergence

Date: 2026-10-06 · Lane: W280 (test files only, no lib edits, no git)

## Diagnosis

`INTERNAL_API_TOKEN` System env is VM-global; async tests mutating it poison
siblings. Two distinct leak channels found (grep `delete_env|put_env` across
`test/` for `INTERNAL_API_TOKEN`):

1. **Poisoner**: `test/xaas/chicago/negative_courts/chicago_authority_courts_test.exs`
   — the ONLY `async: true` module in the tree that mutates the env var
   (CHI-CASE-010 deletes/restores it mid-test). Concurrent async:true tests
   hitting the auth gate received spurious 503s (fail-closed on unset token).
2. **Leaker**: `test/xaas/operations/gymact_surface_test.exs` — refusal tests
   (lines 76/107/115/124) delete the env var and never restore it. Module is
   async:false (exclusive), so no in-run poisoning — but after the module
   finishes, `INTERNAL_API_TOKEN` stays UNSET for every subsequent module:
   `System.fetch_env!("INTERNAL_API_TOKEN")` in
   `test/xaas_web/controllers/health_controller_test.exs:56 auth/1` crashed
   with `System.EnvError` whenever it ran after gymact. Reproduced:
   health+gymact combined = 7 failures; each file alone = green.

All other env-mutating modules (require_internal_api_token_test,
execution_fabric_controller_test, ocel_live_server_chain_test, castle_*
suite, ultracode suite, prometheus_query_controller_test) are already
`async: false` — ExUnit runs those exclusively; no change needed.

The plug (`lib/xaas_web/plugs/require_internal_api_token.ex:95,103`) reads
`System.get_env("INTERNAL_API_TOKEN")` per request, so Application-env
migration would have been the lib-side fix; not needed — the two test-side
changes below close the class with the smallest blast radius.

## Diff (2 files, both test files)

1. `test/xaas/chicago/negative_courts/chicago_authority_courts_test.exs`
   — `async: true` → `async: false` with rationale comment.
2. `test/xaas/operations/gymact_surface_test.exs`
   — added `setup_all` + `on_exit` that restores the pre-module value of
   `INTERNAL_API_TOKEN` (module remains async:false; restore-once-after-
   module is sufficient for exclusive execution).

## Verification (real output, MIX_ENV=test, INTERNAL_API_TOKEN=dev-e2e-token)

- Gate 1: `mix test test/xaas_web/plugs test/xaas_web/controllers/execution_fabric_controller_test.exs test/xaas/chicago/negative_courts/chicago_authority_courts_test.exs`
  → `18 passed` (was the poisoner's own file plus the gate files)
- Gate 2 (W158 spot files, combined — previously 7 failed):
  `mix test test/xaas_web/controllers/health_controller_test.exs test/xaas/operations/gymact_surface_test.exs`
  → `16 passed`
- Gate 1 rerun post-gymact-fix: `13 passed`
- Pre-fix evidence: health alone 7/7 passed; gymact alone 9/9 passed;
  combined 9/16 with `System.EnvError: INTERNAL_API_TOKEN is not set` in
  `auth/1` — the leak, not a product bug.

Standing: PARTIAL_ALIVE — the two W158-repro gates are green; full-suite
convergence is the coordinator's integration gate.
