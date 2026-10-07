# W885b — Exact Court Census (closes W882 open residue)

Lane W885b (second W885 instance; W885 id held by final-gate-precheck receipt).
Subject: /Users/sac/xaas, branch feat/playwright-surface, HEAD a0723bf6 + working-tree delta.
No commit (lane contract); no build root. Output file: this census only.

## Method

Real greps only, 2026-10-07. Candidate set = `git status --porcelain` entries
under `test/` and `e2e/` (`.exs`/`.cjs`), with untracked directory entries
(`test/xaas/ledger/`, `test/w707_tmp/`) expanded. Each file mapped to its
receipt(s) by grepping `docs/sjira/v26.10.6/plans/` for the basename
(top 3 receipt hits shown). Test count = `grep -c 'test "'` (ExUnit) plus
`grep -c '^\s*test('` (Playwright cjs); doctest directives counted separately
(`grep -c '^\s*doctest'`). Classified per-file below. Excluded as non-courts:
`e2e/global-setup.cjs` and `e2e/seed-library.exs` (helpers/fixtures, assert
nothing); `test/w707_tmp/w707_probe_test.exs` (throwaway probe, W850 commit
manifest marks it "possibly delete" — 1 test, excluded from totals).

## Totals

- Candidate set: 114 files, 1,052 test declarations, 5 doctest directives.
- **Court files: 111** (108 ExUnit + 3 Playwright/cjs, including the
  pre-existing wave-modified `e2e/next-read-ml.spec.cjs`).
- **Tests: 1,051** test declarations (+5 doctest directives).
- W882's grid figure "~25 new courts" understates by ~4.4x; exact count is
  111 court files. One-line correction appended to the grid entry.

## Census table (machine-generated from /tmp/census.tsv greps)

| file | receipt(s) (top 3) | tests | EU-AIA |
|---|---|---|---|
| e2e/a2a-marking.spec.cjs | w688-playwright-marking w752-e2e-validation  | 5 (+0 doctests) |  |
| e2e/next-read-ml.spec.cjs | w381-pw-skips-adjudication w752-e2e-validation w214-staging-sequence  | 6 (+0 doctests) |  |
| test/eu_ai_act/airo_grounding_test.exs | w661-grounding-rewitness w702-gymact-gaps  | 7 (+0 doctests) | yes |
| test/eu_ai_act/art15_deepening_test.exs | w886-register-update w676-margin-hardening  | 18 (+0 doctests) | yes |
| test/eu_ai_act/art50_deepening_test.exs | w694-os-register-rederivation w662-euaia-aggregation-9  | 7 (+0 doctests) | yes |
| test/eu_ai_act/art73_chain_deepening_test.exs | w662-euaia-aggregation-9 w669-art73-chain-deepening  | 8 (+0 doctests) | yes |
| test/eu_ai_act/art86_rights_deepening_test.exs | w710-art86-deepening w672-flake-adjudication  | 4 (+0 doctests) | yes |
| test/eu_ai_act/art99_enforcement_deepening_test.exs | w696-art99-deepening  | 7 (+0 doctests) | yes |
| test/eu_ai_act/counterfactual_deepening_test.exs | w692-counterfactual-deepening  | 12 (+0 doctests) | yes |
| test/eu_ai_act/counterfactual_test.exs | w654-env-fix w634-art14a-counterfactual w645-euaia-aggregation-7  | 26 (+0 doctests) | yes |
| test/eu_ai_act/eyerun_wire_deepening_test.exs | w706-eyerun-wire  | 5 (+0 doctests) | yes |
| test/eu_ai_act/not_applicable_completeness_test.exs | w843-na-completeness  | 5 (+0 doctests) | yes |
| test/eu_ai_act/title_i_test.exs | w607-349-41-closures w645-euaia-aggregation-7 w645c-euaia-aggregation-8  | 9 (+0 doctests) | yes |
| test/eu_ai_act/title_ii_deepening_test.exs | w670-euaia-gate-rerun w691-title-ii-deepening  | 19 (+0 doctests) | yes |
| test/eu_ai_act/title_ii_test.exs | w655-title-ii-dedupe w645-euaia-aggregation-7 w645c-euaia-aggregation-8  | 11 (+0 doctests) | yes |
| test/eu_ai_act/title_iii_test.exs | w525-title-vi-xiii w779-opengap-tag w532-art9-13-14-gaps  | 4 (+0 doctests) | yes |
| test/eu_ai_act/title_iv_v_test.exs | w673-wasm4pm-serde-pin w653b-binary-leg w779-opengap-tag  | 3 (+0 doctests) | yes |
| test/eu_ai_act/title_vi_xiii_test.exs | w525-title-vi-xiii w627-art73-flips w622-euaia-aggregation-4  | 4 (+0 doctests) | yes |
| test/xaas_web/a2a_v1_wire_deepening_test.exs | w772-a2a-transition-guard w699-a2a-v1-wire-deepening  | 9 (+0 doctests) |  |
| test/xaas_web/dev_routes_court_test.exs | w774-dev-routes-court  | 7 (+0 doctests) |  |
| test/xaas_web/eu_ai_act_export_deepening_test.exs | w771-export-deepening  | 10 (+0 doctests) |  |
| test/xaas_web/execution_fabric_deepening_test.exs | w745-execution-fabric-deepening w824-quiescent-fabric-tie  | 15 (+0 doctests) |  |
| test/xaas_web/health_court_test.exs | w836-health-court w861-evidence-pack-refresh  | 12 (+0 doctests) |  |
| test/xaas_web/json_api_surface_court_test.exs | w805-jsonapi-surface-court  | 7 (+0 doctests) |  |
| test/xaas_web/jsonapi_content_negotiation_test.exs | w874-ultracode-addendum w817-negotiation-court  | 16 (+0 doctests) |  |
| test/xaas_web/mcp_tools_deepening_test.exs | w800-mcp-tools-deepening  | 6 (+0 doctests) |  |
| test/xaas_web/next_read_live_deepening_test.exs | w766-nextread-live-deepening  | 4 (+0 doctests) |  |
| test/xaas_web/ontop_proxy_deepening_test.exs | w794-raw-body-fix w776-ontop-proxy-deepening  | 11 (+0 doctests) |  |
| test/xaas_web/plug_mount_order_court_test.exs | w703-plug-order-court  | 4 (+0 doctests) |  |
| test/xaas_web/quiescent_fabric_tie_test.exs | w824-quiescent-fabric-tie w844-quiescent-envelope  | 8 (+0 doctests) |  |
| test/xaas_web/require_internal_api_token_deepening_test.exs | w881-manifest-final w769-security-resources-deepening  | 16 (+0 doctests) |  |
| test/xaas_web/resolve_org_actor_deepening_test.exs | w743-resolve-org-actor-deepening w812-org-resolution-coverage  | 13 (+0 doctests) |  |
| test/xaas_web/rpc_surface_deepening_test.exs | w820-ts-adoption-verify w813-rpc-surface-deepening  | 11 (+0 doctests) |  |
| test/xaas_web/sensitive_resources_routing_court_test.exs | w829-sensitive-routing-court w861-evidence-pack-refresh  | 5 (+0 doctests) |  |
| test/xaas_web/stripe_webhook_deepening_test.exs | w775-stripe-webhook-deepening  | 10 (+0 doctests) |  |
| test/xaas_web/ts_codegen_drift_court_test.exs | w837-ts-drift-court w849-generated-surface-census  | 3 (+0 doctests) |  |
| test/xaas_web/witness_live_court_test.exs | — | 4 (+0 doctests) |  |
| test/xaas/a2a_resources_deepening_test.exs | w772-a2a-transition-guard w751-a2a-resources-deepening  | 11 (+0 doctests) |  |
| test/xaas/accounts_deepening_test.exs | w727-accounts-deepening w786-onetime-partition  | 15 (+0 doctests) |  |
| test/xaas/accounts/token_revocation_test.exs | w694-os-register-rederivation w392-os12-migration-staging w191-final-hazards  | 6 (+0 doctests) |  |
| test/xaas/actuation/quiescent_stop_deepening_test.exs | w704-quiescent-deepening w824-quiescent-fabric-tie  | 7 (+0 doctests) |  |
| test/xaas/actuation/run_idempotency_deepening_test.exs | w753-cycle-log-refresh w749-runtime-contract-refresh  | 10 (+0 doctests) |  |
| test/xaas/ash_a2a_runtime_config_court_test.exs | w856-dev-config-pin w720-runtime-config-court  | 10 (+0 doctests) |  |
| test/xaas/billing_deepening_test.exs | w729-billing-deepening w738-ledger-deepening  | 13 (+0 doctests) |  |
| test/xaas/billing/approval_sla_credit_apply_test.exs | w799-reversal-deepening w835-sla-exemption  | 5 (+0 doctests) |  |
| test/xaas/bridges/ferroplan_deepening_test.exs | w716-ferroplan-bridge-deepening  | 12 (+0 doctests) |  |
| test/xaas/bridges/registry_deepening_test.exs | w767-registry-deepening  | 14 (+0 doctests) |  |
| test/xaas/castle_execute_court_test.exs | w828-castle-execute-court  | 10 (+0 doctests) |  |
| test/xaas/conference_deepening_test.exs | w715-conference-deepening w795-conference-invariants  | 11 (+0 doctests) |  |
| test/xaas/coupling_deepening_test.exs | w735-coupling-deepening  | 16 (+0 doctests) |  |
| test/xaas/generated/registry_drift_guard_test.exs | w350-registry-drift-guard w849-generated-surface-census  | 1 (+0 doctests) |  |
| test/xaas/generation_deepening_test.exs | w736-generation-deepening  | 7 (+0 doctests) |  |
| test/xaas/governance/approval_backup_retention_change_test.exs | w740-double-approve-guard w722-governance-deepening  | 2 (+0 doctests) |  |
| test/xaas/governance/export_token_deepening_test.exs | w769-security-resources-deepening w792-approver-wiring  | 16 (+0 doctests) |  |
| test/xaas/governance/multitenant_approval_deepening_test.exs | w740-double-approve-guard w722-governance-deepening  | 10 (+0 doctests) |  |
| test/xaas/governance/paper_trail_deepening_test.exs | w788-paper-trail-deepening  | 4 (+0 doctests) |  |
| test/xaas/governance/security_resources_deepening_test.exs | w769-security-resources-deepening w812-org-resolution-coverage  | 20 (+0 doctests) |  |
| test/xaas/graphlaw_deepening_test.exs | w731-graphlaw-deepening  | 13 (+0 doctests) |  |
| test/xaas/igniter_deepening_test.exs | w734-igniter-deepening  | 11 (+0 doctests) |  |
| test/xaas/ledger_deepening_test.exs | w835-sla-exemption w762-transfer-sufficiency  | 12 (+0 doctests) |  |
| test/xaas/ledger/reversal_deepening_test.exs | w799-reversal-deepening w835-sla-exemption  | 5 (+0 doctests) |  |
| test/xaas/library/checkout_policy_deepening_test.exs | w809-return-guard w796-checkout-policy-deepening  | 12 (+0 doctests) |  |
| test/xaas/library/embedding_deepening_test.exs | w787-embedding-deepening  | 12 (+0 doctests) |  |
| test/xaas/library/nextread_deepening_test.exs | w742-nextread-deepening w787-embedding-deepening  | 9 (+0 doctests) |  |
| test/xaas/library/persona_grant_deepening_test.exs | w718-persona-grant-deepening  | 5 (+0 doctests) |  |
| test/xaas/library/pubsub_publish_court_test.exs | w850-nextread-readme-verify w838-pubsub-publish-court  | 9 (+0 doctests) |  |
| test/xaas/map_update_dual_safe_test.exs | w694-os-register-rederivation w659-xaas-dual-safe w705-wasm4pm-ex4pm-gaps  | 9 (+0 doctests) |  |
| test/xaas/marketplace_deepening_test.exs | w733-marketplace-deepening  | 17 (+0 doctests) |  |
| test/xaas/multitenancy_deepening_test.exs | w789-multitenancy-deepening  | 9 (+0 doctests) |  |
| test/xaas/ocel_deepening_test.exs | w881-manifest-final w758-ocel-fold  | 8 (+0 doctests) |  |
| test/xaas/ontology/staleness_task_court_test.exs |  | 7 (+0 doctests) |  |
| test/xaas/operations/audit_log_deepening_test.exs | w728-audit-log-deepening  | 4 (+0 doctests) |  |
| test/xaas/operations/capability_liveness_deepening_test.exs | w768-liveness-alive-gate w750-liveness-deepening  | 9 (+0 doctests) |  |
| test/xaas/operations/gymact_surface_deepening_test.exs | w707-gymact-seal-fix w674-gymact-deepening  | 11 (+0 doctests) |  |
| test/xaas/operations/incident_lifecycle_deepening_test.exs | w818-incident-guards w793-incident-lifecycle-deepening  | 18 (+0 doctests) |  |
| test/xaas/operations/incident_test.exs | w818-incident-guards w793-incident-lifecycle-deepening  | 11 (+0 doctests) |  |
| test/xaas/operations/route_castle_run_surface_test.exs | w858-route-castle-surface  | 10 (+0 doctests) |  |
| test/xaas/platform/platform_route_deepening_test.exs | w808-approve-route w792-approver-wiring  | 19 (+0 doctests) |  |
| test/xaas/platform/webhook_deepening_test.exs | w775-stripe-webhook-deepening w725-webhook-deepening  | 4 (+0 doctests) |  |
| test/xaas/release_audit_enoent_court_test.exs | w885-final-gate-precheck w889b-manifest-addendum  | 4 (+0 doctests) |  |
| test/xaas/sa2a_bridge_deepening_test.exs | w741-sa2a-deepening  | 14 (+0 doctests) |  |
| test/xaas/sa2a_computation_boundary_test.exs | w853-computation-doctests w763-sa2a-boundary-court  | 21 (+0 doctests) |  |
| test/xaas/sa2a_route_surface_test.exs | w831-exclusions-guard w810-route-surface  | 25 (+0 doctests) |  |
| test/xaas/schema_migration_consistency_test.exs | w846-schema-consistency  | 6 (+0 doctests) |  |
| test/xaas/security_deepening_test.exs | w730-security-deepening  | 12 (+0 doctests) |  |
| test/xaas/semantics/airo_risk_mapping_test.exs | w661-grounding-rewitness w702-gymact-gaps  | 9 (+0 doctests) |  |
| test/xaas/semantics/art12_chain_court_test.exs | w679-malfunction-fix w641-semantics-integration  | 9 (+0 doctests) |  |
| test/xaas/semantics/computation_doctest_test.exs | w853-computation-doctests  | 0 (+4 doctests) |  |
| test/xaas/semantics/dataset_admission_test.exs | w630-totality-fix w676-margin-hardening  | 9 (+0 doctests) |  |
| test/xaas/semantics/declared_metrics_staleness_test.exs | w697-declared-metrics-staleness w797-corpus-readme-2  | 10 (+0 doctests) |  |
| test/xaas/semantics/eu_ai_act_admission_test.exs | w654-env-fix w630-totality-fix w500-art5-admission  | 25 (+0 doctests) |  |
| test/xaas/semantics/eu_ai_act_refusal_closed_set_test.exs | w732-closure-repair w706-trio-gaps  | 4 (+0 doctests) |  |
| test/xaas/semantics/ferroplan_airo_pin_test.exs | w693-ferroplan-airo-pin w668-airo-ledger-verification  | 8 (+0 doctests) |  |
| test/xaas/semantics/incident_report_test.exs | w607-349-41-closures w679-malfunction-fix  | 9 (+0 doctests) |  |
| test/xaas/semantics/jcs_doctest_test.exs | w885-final-gate-precheck w889b-manifest-addendum  | 0 (+1 doctests) |  |
| test/xaas/semantics/jcs_property_test.exs | w617-property-deepening w851-jcs-doctests  | 4 (+0 doctests) |  |
| test/xaas/semantics/master_equation_composition_stress_test.exs | w719-me-stress  | 2 (+0 doctests) |  |
| test/xaas/semantics/refusal_atom_census_test.exs | w713-refusal-census w797-corpus-readme-2  | 6 (+0 doctests) |  |
| test/xaas/semantics/robust_margin_test.exs | w630-totality-fix w508-art15-margin w676-margin-hardening  | 12 (+0 doctests) |  |
| test/xaas/semantics/vulnerability_lifecycle_test.exs | w732-closure-repair w547-gap-flips  | 15 (+0 doctests) |  |
| test/xaas/telemetry/ocel_egress_deepening_test.exs | w663b-postcommit-gates w666-ocel-egress-deepening  | 6 (+0 doctests) |  |
| test/xaas/telemetry/ocel_forwarder_deepening_test.exs | w764-forwarder-deepening  | 5 (+0 doctests) |  |
| test/xaas/temporal_memory_deepening_test.exs | w724-temporal-deepening  | 4 (+0 doctests) |  |
| test/xaas/ultracode/lease_kernel_deepening_test.exs | w874-ultracode-addendum w811-lease-kernel-deepening w840-clock-seam  | 23 (+0 doctests) |  |
| test/xaas/ultracode/run_receipt_deepening_test.exs | w804-epoch-dedup w737-run-cycle-index  | 10 (+0 doctests) |  |
| test/xaas/w838_probe_test.exs |  | 1 (+0 doctests) |  |
| test/xaas/wasm4pm_serde_surface_pin_test.exs | w673-wasm4pm-serde-pin  | 5 (+0 doctests) |  |
| test/xaas/witness/catalog_durability_test.exs | w889-key-rotation-doc w709-witness-durability  | 4 (+0 doctests) |  |
| test/xaas/witness/witness_surface_deepening_test.exs | w698-witness-deepening w726-witness-constraint-fix  | 11 (+0 doctests) |  |
| test/xaas/workbench_deepening_test.exs | w748-workbench-deepening  | 8 (+0 doctests) |  |
| test/xaas/zoe_deepening_test.exs | w744-zoe-deepening  | 15 (+0 doctests) |  |

## Standing

- ALIVE as a census: real greps over real files, 2026-10-07, exact subject
  HEAD a0723bf6 + working tree. This is a count, not a test run — no `mix
  test` was executed this lane; the 1347-green-gate receipt
  (`w821-terminal-census-2.md`) remains the test-run evidence.
- Open residue transferred to the final gate: `test/xaas/ontology/staleness_task_court_test.exs`
  and `test/xaas/release_audit_enoent_court_test.exs` have no named receipt
  in `plans/` (staleness_task is "W697/W694 — VERIFY-AT-COMMIT" per the W850
  commit manifest; release_audit_enoent is the court for the `w845-audit-enoent.md`
  fix but is unreceipted under its own name); `w838_probe_test.exs` is
  unreceipted and marked "possibly delete".
