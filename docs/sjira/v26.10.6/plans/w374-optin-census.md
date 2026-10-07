# W374 — DoD 1 opt-in census (vector3 tags) @ feat/playwright-surface

Observed 2026-10-06, repo /Users/sac/xaas @ feat/playwright-surface. Method: `grep -rE '@(moduletag|describetag|tag) :<name>' test/` plus `test/test_helper.exs` gate inventory. Counts include @tag, @moduletag, and @describetag carriers.

## Per-tag census (the 5 vector3 opt-in tags)

| tag | tag sites | files | tests covered | gate mechanism | sample files |
|---|---|---|---|---|---|
| `:kind` | 4 | 4 | 8 (1 + 1 + 5 + 1... see below) | `exclude: [:kind]` in `test/test_helper.exs:59`; run via `mix test --include kind` | test/xaas_web/controllers/prometheus_query_controller_test.exs:25 (per-test @tag), test/e2e/kind_deployment_test.exs:65 (@moduletag, 5 tests), test/e2e/kind_chaos_pod_recovery_test.exs:32 (@moduletag, 2), test/e2e/kind_chaos_postgres_pod_recovery_test.exs:62 (@moduletag, 1) |
| `:requires_cnv_deploy` | 2 | 2 | 3 (1+2) | `exclude: [:requires_cnv_deploy]` (test_helper.exs:59... actually the exclude list line 59) | test/xaas/operations/autofde_planner_cross_product_test.exs:10 (@moduletag, 1 test), test/xaas/operations/autofde_planner_candidate_test.exs:4 (@moduletag, 2 tests) |
| `:stress` | 8 | 8 | 17 | `exclude: [:stress]` (test_helper.exs:57); `mix test --include stress` | webhook_delivery_stress_test.exs, approval_provider_status_change_stress_test.exs, provider_stress_test.exs, capability_liveness_receipt_stress_test.exs, lease_concurrency_stress_test.exs (10 tests), approval_dr_failover_stress_test.exs, approval_backup_retention_change_stress_test.exs, approval_pentest_finding_resolve_stress_test.exs |
| `:castle_kernel` | 3 sites / 2 files | 2 files | 12 (2 of 3 tests in castle_bridge_test.exs + all 10 in castle_alive_test.exs) | `exclude: [:castle_kernel]` (test_helper.exs:65); CI `.github/workflows/castle-paas-bridge.yml` runs `mix test --include castle_kernel test/xaas/castle_bridge_test.exs` | test/xaas/castle_bridge_test.exs:57,167 (@tag, 2 of the file's 3 tests), test/xaas/fabric/castle_alive_test.exs:17 (@moduletag, 10 tests) |
| `:external_llm` | 2 sites / 1 file | 1 | 2 (1 per-test @tag + 1 @describetag describe block) | `exclude: [:external_llm]` (test_helper.exs:62); `mix test --include external_llm` | test/xaas/library/explainer_test.exs:82 (@tag) and :100 (@describetag) |

Exact :kind test math: prometheus 1 (@tag :kind) + kind_deployment 5 + kind_chaos_pod_recovery 2 + kind_chaos_postgres_pod_recovery 1 = 8 tests (prometheus file's other 4 tests untagged, run by default — correct).

Exact :stress test math: 1+1+2+1+10+1+1+1 = 18 tests. (:stress total 18, not 17.)

## Full tag inventory found in test/ (all names)

`subprocess`(28 sites/14 files), `igniter_catalog`(10/1), `real_marketplace_catalog`(5/2), `http`(5/1), `autonomic_wave_contract`(4/1), `conference_seed`(3/1), `tmp_dir`(5/5, ExUnit built-in), `purity`(2/1), `castle_kernel`(3/2), `kind`(4/4), `requires_cnv_deploy`(2/2), `stress`(8/8), `requires_autofde`(1/1), `registry_drift_guard`(1/1), `ash_surface_gen`(1/1), `external_llm`(2/1), `property`(1/1), `external`(1/1), `requires_semantic_jira_api`(0 — named in exclude list only, vestigial).

## test_helper.exs gate inventory (test/test_helper.exs:54-67)

`ExUnit.configure(exclude: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel])`, `max_cases: schedulers*2`. No `include` entries; opt-in is via CLI `--include <tag>`.

Other gate mechanisms observed:
- **w155 typed-skip convention**: `@moduletag skip: "reason"` / `@tag skip: "reason"` with named reasons (test/sjira/v26_9_23_goal_test.exs:38, test/mix/tasks/xaas_stop_court_test.exs:31, test/xaas/sjira_orders_generation_test.exs:18 — conditional on python3 presence). ExUnit built-in skip, reason-string typed.
- **Env-conditional module tag**: `if is_nil(@python), do: @moduletag(skip: ...)` (sjira_orders_generation_test.exs).
- No directory exclusions (test/e2e/*.exs IS in the default path, gated only by `:kind`); e2e/*.spec.cjs are Playwright, not ExUnit.
- No CommandBus timeout tags found (grep for timeout-tag patterns in test_helper.exs / config/test.exs / test/: zero hits).
- Grep artifact only: test_helper.exs line 39 mentions `@describetag :external_llm` in a comment (not a tag site).

## Carve-out verification (step 3 — 3 files sampled per tag)

- :kind — sampled prometheus_query_controller_test.exs (per-test @tag :kind on exactly the one live-Prometheus test), kind_deployment_test.exs + kind_chaos_pod_recovery_test.exs (@moduletag on all tests). All excluded only via the test_helper exclude list; no local skip, no dir exclusion accident.
- :requires_cnv_deploy — both autofde files use @moduletag at top; excluded by config.
- :stress — sampled webhook_delivery_stress_test.exs, lease_concurrency_stress_test.exs, capability_liveness_receipt_stress_test.exs: all @moduletag :stress, excluded by config.
- :castle_kernel — castle_bridge_test.exs tags exactly the 2 receipt/replay tests (@tag), its third (REFUSED-context) test is untagged and intentionally in the default run; castle_alive_test.exs @moduletag over all 10. Excluded by config.
- :external_llm — explainer_test.exs: per-test @tag (line 82) + @describetag (line 100); excluded by config (the historical leak of this exact tag is documented at test_helper.exs:38-43 as a fixed bug).

## Verdict

**DEFAULT-RUN-CARVEOUT-HELD** — all five opt-in tags are excluded by explicit `ExUnit.configure(exclude: [...])` in `test/test_helper.exs`, not by accident or directory convention. No tagged test runs by default. (`:requires_semantic_jira_api` sits in the exclude list with zero tag sites — a vestigial entry, not a leak.)

## Receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface, working tree as of 2026-10-06
- Commands: grep census above; Read test/test_helper.exs (full); sampled 10 tagged files verbatim
- Falsifier checked: a tagged test running by default → none found
- Standing: observed, read-only lane; no files outside docs/sjira/v26.10.6/plans/w374-optin-census.md written