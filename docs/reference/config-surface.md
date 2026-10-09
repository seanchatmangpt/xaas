# Config surface reference
GENERATED — do not edit. Source of truth: `lib/` (Elixir sources).
Regenerate: `python3 scripts/gen_config_surface_ref.py`.
Verify: `python3 scripts/gen_config_surface_ref.py --check` (byte-identical re-extract).

Every documented key traces to a real source line. This is the atom/string-key
config surface of the xaas OTP app — the coverage denominator for key-set
coverage gates (the [109]-class atom/string-key surface items).

## Application config keys (`:xaas`)

Every `Application.get_env/fetch_env!/put_env(:xaas, :key, ...)` call site, deduped per key (first call site listed).

| Key | First call site |
|---|---|
| `:ash_domains` | `lib/mix/tasks/xaas.release_audit.ex:305` |
| `:castle_adapter_profiles` | `lib/xaas/castle.ex:795` |
| `:castle_kernel_module` | `lib/xaas/castle.ex:59` |
| `:chicago_executive_loader` | `lib/xaas_web/live/chicago/seller_live.ex:16` |
| `:chicago_subject_loader` | `lib/xaas_web/live/chicago/seller_live.ex:395` |
| `:cnv_deploy_base_url` | `lib/mix/tasks/xaas.close_coverage_gap.ex:18` |
| `:declared_metrics_root` | `lib/xaas/semantics/declared_metrics.ex:66` |
| `:ex4pm_ocel_ingest_timeout_ms` | `lib/xaas/telemetry/ocel_forwarder.ex:212` |
| `:ex4pm_ocel_ingest_url` | `lib/xaas/telemetry/ocel_forwarder.ex:208` |
| `:ex4pm_ontology_check` | `lib/xaas/ontology/ex4pm_staleness.ex:67` |
| `:graphlaw_registry_path` | `lib/xaas/graphlaw/catalog.ex:29` |
| `:graphlaw_wasm_sha256` | `lib/xaas/semantics/graphlaw_wasm.ex:282` |
| `:health_node_boot_at_override` | `lib/xaas_web/controllers/health_controller.ex:312` |
| `:library_default_grade` | `lib/xaas/library/config.ex:180` |
| `:library_default_school_id` | `lib/xaas/library/config.ex:140` |
| `:library_grade_fit_fallback` | `lib/xaas/library/config.ex:122` |
| `:library_grade_fit_thresholds` | `lib/xaas/library/config.ex:114` |
| `:library_grade_range` | `lib/xaas/library/config.ex:193` |
| `:library_pubsub_topics` | `lib/xaas/library/config.ex:130` |
| `:library_ranker_weights` | `lib/xaas/library/config.ex:48` |
| `:library_recommendation_limit` | `lib/xaas/library/config.ex:206` |
| `:marketplace_catalog_source` | `lib/xaas_web/live/marketplace_catalog_live.ex:15` |
| `:ontop_base_url` | `lib/xaas_web/controllers/health_controller.ex:328` |
| `:ontop_endpoint` | `lib/xaas_web/controllers/health_controller.ex:224` |
| `:ontop_proxy_http_client` | `lib/xaas_web/controllers/health_controller.ex:325` |
| `:pplan_durable_store` | `lib/xaas/bridges/pplan.ex:23` |
| `:prov_origin` | `lib/xaas_web/plugs/prov_origin_header.ex:22` |
| `:ultracode_asdf_data_dir` | `lib/mix/tasks/xaas.episode.ex:379` |
| `:ultracode_backlog_scripts` | `lib/xaas/ultracode/autonomic.ex:682` |
| `:ultracode_capability_full_closure` | `lib/xaas/ultracode/capability_resolver.ex:362` |
| `:ultracode_capability_sources` | `lib/xaas/ultracode/capability_resolver.ex:247` |
| `:ultracode_clock` | `lib/xaas/ultracode/duration_budget.ex:40` |
| `:ultracode_construction_recipes` | `lib/xaas/sa2a/route.ex:340` |
| `:ultracode_default_duration_budget_seconds` | `lib/xaas/ultracode/duration_budget.ex:52` |
| `:ultracode_default_provider` | `lib/xaas/ultracode/provider_registry.ex:130` |
| `:ultracode_dispatch_cli_dir` | `lib/xaas/ultracode/dispatch.ex:889` |
| `:ultracode_dispatch_node_path` | `lib/xaas/ultracode/dispatch.ex:904` |
| `:ultracode_engine_providers` | `lib/xaas/ultracode/engine.ex:166` |
| `:ultracode_engine_runner` | `lib/xaas/ultracode/run.ex:792` |
| `:ultracode_engine_worker` | `lib/xaas/ultracode/engine.ex:420` |
| `:ultracode_frontier_source` | `lib/xaas/ultracode/recurrence.ex:249` |
| `:ultracode_ggen_bin` | `lib/xaas/ultracode/capability_resolver/pack_generator.ex:97` |
| `:ultracode_ggen_marketplace_root` | `lib/xaas/ultracode/capability_resolver/pack_generator.ex:86` |
| `:ultracode_judge_accept_court_verified_partial` | `lib/xaas/ultracode/autonomic.ex:1060` |
| `:ultracode_ocel_log_emitter` | `lib/xaas/ultracode/run_validation.ex:239` |
| `:ultracode_pool_capacity` | `lib/xaas/ultracode/lease.ex:352` |
| `:ultracode_provider_breaker_base_ms` | `lib/xaas/ultracode/provider_recovery.ex:320` |
| `:ultracode_provider_breaker_threshold` | `lib/xaas/ultracode/provider_recovery.ex:316` |
| `:ultracode_provider_tools` | `lib/xaas/ultracode/lease.ex:769` |
| `:ultracode_providers` | `lib/xaas/ultracode/provider_registry.ex:104` |
| `:ultracode_repos` | `lib/mix/tasks/xaas.episode.ex:343` |
| `:ultracode_repos_file` | `lib/xaas/ultracode/repos.ex:415` |
| `:ultracode_sa2a_capability_endpoint` | `lib/xaas/ultracode/capability_resolver/source/sa2a.ex:41` |
| `:ultracode_self_digest` | `lib/xaas/ultracode/self_digest_worker.ex:64` |
| `:ultracode_sensing_profiles` | `lib/xaas/ultracode/sensing.ex:137` |
| `:ultracode_standing_audit` | `lib/xaas/ultracode/campaign.ex:647` |
| `:ultracode_standing_audit_timeout_ms` | `lib/xaas/ultracode/campaign.ex:650` |
| `:ultracode_subagent_max_turns` | `lib/xaas/ultracode/dispatch.ex:637` |
| `:ultracode_suite_health_dir` | `lib/xaas/ultracode/suite_health.ex:219` |
| `:ultracode_target_suites` | `lib/xaas/ultracode/verifier.ex:1008` |
| `:ultracode_ticket_dir` | `lib/mix/tasks/xaas.semantic.materialize.ex:102` |
| `:ultracode_verifier_suites` | `lib/mix/tasks/xaas.episode.ex:354` |
| `:ultracode_wave_loop_claim_grace_seconds` | `lib/xaas/ultracode/wave_loop.ex:688` |
| `:ultracode_wave_loop_concurrency` | `lib/xaas/ultracode/wave_loop.ex:494` |
| `:ultracode_wave_loop_concurrency_max` | `lib/xaas/ultracode/wave_loop.ex:499` |
| `:ultracode_wave_loop_dispatch_grace_seconds` | `lib/xaas/ultracode/wave_loop.ex:460` |
| `:ultracode_wave_loop_dispatcher` | `lib/xaas/ultracode/wave_loop.ex:762` |
| `:ultracode_wave_loop_ocel_path` | `lib/xaas/ultracode/wave_loop/ocel.ex:72` |
| `:ultracode_wave_loop_telemetry_path` | `lib/xaas/ultracode/self_digest_worker.ex:68` |
| `:ultracode_wave_loop_timeout_seconds` | `lib/xaas/ultracode/wave_loop.ex:1224` |
| `:ultracode_wave_rearm` | `lib/xaas/ultracode/duration_budget.ex:193` |
| `:ultracode_wave_repo_caps` | `lib/xaas/ultracode/wave_plan.ex:137` |
| `:ultracode_wave_runner` | `lib/xaas/ultracode/campaign.ex:266` |
| `:ultracode_worktree_root` | `lib/mix/tasks/xaas.episode.ex:351` |

Total: 74 config keys.

## EU AI Act refusal atoms (`Xaas.Semantics.EuAiActAdmission`)

The typed refusal atoms declared in `@typedref_atoms` (declaration order), with their string-key form in the AIRO risk mapping.

| Atom | String form | Declared | AIRO mapping |
|---|---|---|---|
| `:35` | `35` | `lib/xaas/semantics/eu_ai_act_admission.ex` | — |
| `:36` | `36` | `lib/xaas/semantics/eu_ai_act_admission.ex` | — |
| `:37` | `37` | `lib/xaas/semantics/eu_ai_act_admission.ex` | — |
| `:38` | `38` | `lib/xaas/semantics/eu_ai_act_admission.ex` | — |
| `:39` | `39` | `lib/xaas/semantics/eu_ai_act_admission.ex` | — |
| `:40` | `40` | `lib/xaas/semantics/eu_ai_act_admission.ex` | — |
| `:41` | `41` | `lib/xaas/semantics/eu_ai_act_admission.ex` | — |
| `:42` | `42` | `lib/xaas/semantics/eu_ai_act_admission.ex` | — |
| `:45` | `45` | `lib/xaas/semantics/eu_ai_act_admission.ex` | — |

Total: 9 refusal atoms (8 Art. 5(1) partitions + `REFUSED_EUAIA_MALFORMED_CANDIDATE`).

## Frontier-evidence actuation verdict atoms (`Xaas.Actuation.FrontierEvidence`)

Every `{:error, :atom}` / `{:error, {:atom, ...}}` reason atom in the module, in source order.

| Line | Atom | Form |
|---|---|---|
| 41 | `:unsupported_bundle_schema` | bare |
| 42 | `:fragments_required` | bare |
| 44 | `:bundle_sha256_required` | bare |
| 47 | `:bundle_hash_mismatch` | tupled |
| 51 | `:invalid_frontier_evidence_bundle` | bare |
| 52 | `:invalid_frontier_evidence_bundle` | bare |
| 56 | `:frontier_evidence_bundle_must_be_map` | bare |
| 70 | `:causal_certificate_must_be_map` | bare |
| 82 | `:fragment_producer_required` | bare |
| 85 | `:duplicate_fragment_producer` | tupled |
| 102 | `:producer_key_mismatch` | tupled |
| 110 | `:frontier_fragments_must_be_list_or_map` | bare |
| 120 | `:missing_frontier_producers` | tupled |
| 123 | `:unsupported_frontier_producers` | tupled |
| 140 | `:unsupported_fragment_schema` | tupled |
| 143 | `:fragment_producer_mismatch` | tupled |
| 146 | `:producer_head_required` | tupled |
| 149 | `:standing_required` | tupled |
| 157 | `:artifact_hash_required` | tupled |
| 160 | `:fragment_evidence_required` | tupled |

Total: 20 verdict-atom occurrences.
