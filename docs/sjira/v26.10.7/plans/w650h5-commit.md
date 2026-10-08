# W650h5 — Sweep 3: untracked completed-lane court files (commit receipt)

- **Subject**: `feat/playwright-surface` @ base `45844db6` → head `a99243b7`
  (commits `4229a72e` + `a99243b7`, 36 test files, explicit-pathspec commits, no force).
- **Scope**: all untracked `test/xaas/**/*.exs` at sweep start (74 files), filtered by
  owner-receipt evidence.
- **Gate**: fresh-root compile EXIT=0 (`MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW650h5`); 
  batch run of the 63-file candidate set: **252/256 passed** (44 excluded), all 4 failures
  confined to the 3 excluded files below. Every committed file green in that batch.
- **Mid-flight collision (disclosed)**: concurrent W984dq4/W650h6 sweeps (commits
  `bcf1371d`, `143df2dc`, `45844db6`) landed 24 of the 60 receipt-eligible files while this
  lane was gating. Complement property held exactly: zero overlap with this lane's staged 36;
  every staged file verified NOT-IN-HEAD immediately before commit; no conflict, no clobber.

## Exclusions (typed)

| file | reason | evidence |
|---|---|---|
| test/xaas/causal_receipt/process_receipt_depth_test.exs | OWNER-DEFECT (2 real failures) | `DateTime.shift!/2` undefined (line 74); `refute Map.has_key?(d, :receipt_hash)` contradicted by actual diff/2 output (line 115). Also contains a stray garbage assertion at line 131 (`intent_placholder_guard` placeholder) — left as found, not repaired by this lane. |
| test/xaas/airo/airo_pin_court_test.exs | ENV-DRIFT (pre-existing) | on-disk HEAD of external checkout `ash_atlassian` diverged from ledger pin 43e3d21b7c4e; not a defect of this repo. |
| test/xaas/airo/pin_drift_test.exs | ENV-DRIFT (pre-existing) | receipted drift row for `beam4pm/vendor/ggen-marketplace` no longer matches external checkout reality. |
| test/xaas/conference/registration_terminal_cancel_guard_court_w980do_test.exs | NO-RECEIPT | no owner receipt anywhere under docs/sjira/. (file id w984do) |
| test/xaas/marketplace/catalog_consumption_depth_w984dg_test.exs | NO-RECEIPT | no owner receipt under docs/sjira/. |
| test/xaas/operations/approval_castle_verb_schedule_authority_test.exs | NO-RECEIPT | no owner receipt under docs/sjira/. Note: commit bcf1371d's message claims "approval-castle/verb-schedule court" landed, but the only matching file remains untracked at head a99243b7 — verify against that lane's receipt. |
| test/xaas/self_digest/promotion_pipeline_depth_test.exs | NO-RECEIPT | no owner receipt under docs/sjira/. |
| test/xaas/semantics/vkg/query_depth_test.exs | NO-RECEIPT | no owner receipt under docs/sjira/. |
| test/xaas/sjira/w984dp3_atlassian_cursor_court_test.exs | RUNNING-LANE (w984dp3) + NO-RECEIPT | coordinator-listed running lane. |
| test/xaas/generation/lock_error_roundtrip_w984dj5b2_test.exs | RUNNING-LANE (w984dj5) + NO-RECEIPT | coordinator-listed running lane. |
| test/xaas/generation/lock_persistence_depth_w984dj5_test.exs | RUNNING-LANE (w984dj5) | probe receipt w984dj5-generation.md exists but is itself untracked (lane mid-write). |
| test/xaas/vault/vault_depth_court_test.exs | RUNNING-LANE (w984dl) | probe receipt w984dl-vault-probe.md untracked (lane mid-write). |
| test/xaas/conference/registration_status_transition_court_w650y4_test.exs | NOT-ELIGIBLE-AT-SCAN | created by another lane after this lane's scan; outside this lane's 74-file scope. |

## Staged (committed, 36 files — owner receipts verified on disk)

| file | owner receipt(s) |
|---|---|
| test/xaas/accounts/org_membership_destroy_depth_test.exs | w980i-depth-batch |
| test/xaas/accounts/org_suspension_validation_depth_test.exs | w984cw5-accounts-probe, w984bw-accounts-depth |
| test/xaas/chicago/bridges/graphlaw_assess_deepening_test.exs | w983b-graphlaw-assess-deepening |
| test/xaas/coupling/coupling_depth_test.exs | w984cu-coupling-depth |
| test/xaas/deepening/art_10_2fg_bias_gate_measurement_liveness_test.exs | w984by-corpus-deepening-7 |
| test/xaas/deepening/art_10_2h_10_3_dataset_gate_causality_test.exs | w984a-corpus-deepening-3 |
| test/xaas/deepening/art_13_3e_live_toolchain_pin_test.exs | w984al-corpus-deepening-5 |
| test/xaas/deepening/art_14_4b_causal_briefing_test.exs | w981t-corpus-deepening |
| test/xaas/deepening/art_15_5s3_lifecycle_real_detection_test.exs | w981t-corpus-deepening |
| test/xaas/deepening/art_26_1_governed_actuation_stop_chain_test.exs | w984p-corpus-deepening-4 |
| test/xaas/deepening/art_26_2_human_oversight_assignment_test.exs | w984be-corpus-deepening-6, w984cf-oversight-depth |
| test/xaas/deepening/art_26_5_operation_monitoring_egress_test.exs | w984be-corpus-deepening-6, w984al-corpus-deepening-5 |
| test/xaas/deepening/art_26_6_retention_durable_row_test.exs | w984cf-oversight-depth, w981t-corpus-deepening |
| test/xaas/deepening/art_26_7_worker_notification_liveness_test.exs | w982z-corpus-deepening-2 |
| test/xaas/deepening/art_26_9_art13_information_use_test.exs | w984a-corpus-deepening-3, w984p-corpus-deepening-4 |
| test/xaas/deepening/art_27_1cd_fria_evidence_liveness_test.exs | w982z-corpus-deepening-2 |
| test/xaas/deepening/art_27_1f_materialisation_safeguard_binding_test.exs | w984by-corpus-deepening-7 |
| test/xaas/deepening/art_9_4_zero_config_env_invariance_test.exs | w984be-corpus-deepening-6, w984al-corpus-deepening-5, w984p-corpus-deepening-4 |
| test/xaas/generated/regen_check_court_test.exs | w982g-lspec-wave, w984g-regen-pins-upgrade |
| test/xaas/generation/projection_record_admission_depth_test.exs | w984dj5-generation, w980i-depth-batch |
| test/xaas/governance/approval_deployment_quarantine_lifecycle_depth_test.exs | w984ci-governance-depth |
| test/xaas/governance/audit_export_token_actor_policy_depth_test.exs | w984ay-code-graphql-sweep, w984ar-depth-court, w984cy4-gov-73 |
| test/xaas/governance/freeze_window_deepening_test.exs | w984ci-governance-depth, w984bb-freeze-idempotency |
| test/xaas/governance/pentest_finding_authorization_depth_test.exs | w984aa-depth-batch2, w984cy4-gov-73 |
| test/xaas/marketplace/pack_catalog_depth_test.exs | w984bo-marketplace-depth |
| test/xaas/marketplace/provider_preapprove_lifecycle_test.exs | w980i-depth-batch |
| test/xaas/operations/castle_approval_route_surface_test.exs | w984dk-provenance |
| test/xaas/operations/castle_verb_inventory_policy_floor_test.exs | w984aa-depth-batch2 |
| test/xaas/operations/refusal_ledger_export_depth_test.exs | w984cw4-ops-probe |
| test/xaas/perf/graphlaw_smoke_perf_test.exs | w984ay-code-graphql-sweep, w982x-perf-smoke |
| test/xaas/platform/platform_depth_w984bq_test.exs | w984cn-oban-depth, w984bq-platform-depth |
| test/xaas/research_runtime/identity/standing_court_test.exs | w984cz3-probe |
| test/xaas/semantics/airo_risk_mapping_depth_test.exs | w984bj-semantics-depth, w984ce-airo-dedup |
| test/xaas/semantics/attribution_counterfactual_depth_test.exs | w984av-depth-court2 |
| test/xaas/semantics/robust_margin_depth_test.exs | w984av-depth-court2, w984aa-depth-batch2 |
| test/xaas/tunnel/submit_test.exs | w984cw2-tunnel-depth |

## Standing

- HEAD `a99243b7` = both batches committed, index clean of this lane's files.
- Push: fetch-then-ff to `origin/feat/playwright-surface` (see push line in lane log).
- Build root `_build-laneW650h5` deleted at lane close.
- Residual untracked `test/xaas/**/*.exs` at close: 17 files (exclusions table above + post-scan arrivals from other lanes) — left for their owner lanes / next sweep.
