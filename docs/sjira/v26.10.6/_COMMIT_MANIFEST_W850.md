# Commit Manifest — W850/W867 staging (v26.10.6 consolidation wave)

- Staged by: lane W867 (commit-manifest staging), 2026-10-07
- Subject: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf6
- Source: git status --porcelain at staging time — 108 tracked changes + ~165 untracked entries (incl. 4 untracked dirs).
- Attribution: plan receipts (docs/sjira/v26.10.6/plans/wNNN-*.md Subject / Files-written) cross-checked with W-markers inside hunks (git diff HEAD). Mention-only matches not treated as ownership.
- Convention: each commit <=12 files. St: M=modified, ??=untracked, D=deleted.
## CG-01 · Fleet infra: config + migrations
Message: fix(infra): ash_onetime partition queues + config pins (W786/W803/W822); migrations W726/W786/W804
- config/config.exs [M] — W786 (hunk-marked; ash_onetime Oban queues) — COMMIT
- config/dev.exs [M] — W803 (receipt: ash_a2a block, cluster_size 1->3, fixes W752-F1) — OPERATOR-DECISION
- config/test.exs [M] — W822 (env-overridable test port) — COMMIT
- priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs [??] — W786 (receipt) — OPERATOR-DECISION (dev DB)
- priv/repo/migrations/20261007120000_dedup_orgless_epochs_then_unique_index.exs [??] — W804 (receipt) — OPERATOR-DECISION (dev DB, deletes dup rows)
- priv/repo/migrations/20261007000000_rename_witness_identity_indexes.exs [??] — W726/W783 — COMMIT
- priv/repo/migrations/20261007010000_add_orgless_run_cycle_partial_unique_index.exs [??] — W737/W804 family — VERIFY-AT-COMMIT
## CG-02 · Repairs: governance double-approve guards (W740)
Message: fix(governance): double-approve guards on governance approvals (W740)
- lib/xaas/governance/approval_backup_retention_change.ex [M] — W740 (receipt files-written)
- lib/xaas/governance/approval_deployment_quarantine.ex [M] — W740 (receipt files-written)
- lib/xaas/governance/approval_dr_failover.ex [M] — W740 (receipt files-written)
- lib/xaas/governance/approval_legal_hold_release.ex [M] — W740 (receipt files-written)
- lib/xaas/governance/validations/approval_not_already_approved.ex [??] — W740 (new)
- test/xaas/governance/approval_backup_retention_change_test.exs [M] — W740 (receipt files-written)
## CG-03 · Repairs: billing/ledger (W785/W746/W762/W799/W835)
Message: fix(billing): overdraft policy + SLA-credit idempotency + transfer sufficiency (W785/W746/W762/W799/W835)
- lib/xaas/billing/changes/approval_patch_sla_credit_apply_approve.ex [M] — W785 (receipt) + W799/W835
- lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex [M] — W785 (receipt) + W799/W835
- lib/xaas/billing/changes/subscription_charge_on_activate.ex [M] — W785 (hunk-marked)
- lib/xaas/billing/changes/subscription_prorate_tier_change.ex [M] — W785 (hunk-marked)
- lib/xaas/billing/approval_sla_credit_apply.ex [M] — W746 (hunk-marked)
- lib/xaas/governance/changes/approval_backup_retention_change_charge_overage.ex [M] — W785 (hunk-marked)
- lib/xaas/ledger/transfer.ex [M] — W762/W738 (hunk-marked)
- test/xaas/billing/approval_sla_credit_apply_test.exs [M] — W746/W799/W835 (hunk-marked)
- test/xaas/billing_deepening_test.exs [??] — W729/W746
- test/xaas/ledger_deepening_test.exs [??] — W738/W785
- test/xaas/ledger/ [dir ??] — W799/W835 — enumerate contents at commit time
## CG-04 · Repairs: plugs/actuation/castle/sa2a/checkout/freeze (W794/W773/W780/W828/W831/W809/W801)
Message: fix(core): plug path gate + actuation seal/authority + castle execute court + sa2a route guard (W794/W773/W780/W828/W831/W809/W801)
- lib/xaas_web/plugs/stripe_raw_body_reader.ex [M] — W794 (receipt)
- lib/xaas_web/plugs/ontop_proxy_plug.ex [M] — W794 (receipt)
- lib/xaas/actuation.ex [M] — W773 (sealed_error) + W780 (claim-shaped authority refusal), hunk-marked
- lib/xaas/castle.ex [M] — W828 (hunk-marked)
- test/xaas/castle_execute_court_test.exs [??] — W828 (receipt)
- lib/xaas/sa2a/route.ex [M] — W831 (hunk-marked)
- test/xaas/sa2a_route_surface_test.exs [??] — W810/W831
- lib/xaas/library/checkout.ex [M] — W809/W796 (hunk-marked)
- test/xaas/library/checkout_policy_deepening_test.exs [??] — W796/W809
- lib/xaas/governance/validations/audit_export_token_no_active_freeze_window.ex [??] — W801 (new)
- lib/xaas/governance/audit_export_token.ex [M] — W801 (receipt: +validate on :issue)
- test/xaas/governance/export_token_deepening_test.exs [M] — W801 (hunk-marked; also W765/W769/W792/W834)
## CG-05 · Repairs (cont.): incident/gymact/lease/fabric (W818/W707/W840/W824/W844)
Message: fix(ops): incident terminal guards + gymact seal + lease clock seam + fabric quiescent envelope (W818/W707/W840/W824/W844)
- lib/xaas/operations/incident.ex [M] — W793/W818 (hunk-marked)
- lib/xaas/operations/gymact_surface.ex [M] — W674/W707 (hunk-marked)
- lib/xaas/ultracode/lease.ex [M] — W840 (hunk-marked)
- lib/xaas_web/controllers/execution_fabric_controller.ex [M] — W824 (hunk-marked)
- test/xaas/operations/incident_test.exs [M] — W818 (hunk-marked)
- test/xaas/operations/incident_lifecycle_deepening_test.exs [??] — W793/W818
- test/xaas/operations/gymact_surface_deepening_test.exs [??] — W674/W707
- test/xaas/ultracode/lease_kernel_deepening_test.exs [??] — W811/W840
- test/xaas_web/quiescent_fabric_tie_test.exs [??] — W824/W844
- test/xaas/actuation/quiescent_stop_deepening_test.exs [??] — W704/W824/W844
- test/xaas/actuation/run_idempotency_deepening_test.exs [??] — W747
- test/xaas_web/execution_fabric_deepening_test.exs [??] — W745/W749
## CG-06 · Repairs (cont.): platform approver wiring + routes (W792)
Message: fix(platform): approver wiring across platform routes + requirements (W792)
- lib/xaas/platform/changes/route_feature_flags_approve.ex [M] — W792 (hunk-marked)
- lib/xaas/platform/changes/route_projects_approve.ex [M] — W792 (hunk-marked)
- lib/xaas/platform/changes/route_secrets_approve.ex [M] — W792 (hunk-marked)
- lib/xaas/platform/route_feature_flags.ex [M] — W792 (hunk-marked; also W808/W785/W786) — VERIFY-AT-COMMIT
- lib/xaas/platform/route_projects.ex [M] — W792 (hunk-marked)
- lib/xaas/platform/route_secrets.ex [M] — W792 (hunk-marked)
- lib/xaas/platform/validations/route_feature_flags_requires_approver.ex [M] — W792 (hunk-marked)
- lib/xaas/platform/validations/route_projects_requires_approver.ex [M] — W792 (hunk-marked)
- lib/xaas/platform/validations/route_secrets_requires_approver.ex [M] — W792 (hunk-marked)
- test/xaas/platform/platform_route_deepening_test.exs [??] — W770/W792/W808
- test/xaas/platform/webhook_deepening_test.exs [??] — W725
## CG-07 · Semantics lib (EU-AI-Act closure: W732/W676/W679/W630)
Message: fix(semantics): EU-AI-Act closure repairs — admission/margin/vulnerability/incident (W732/W676/W679/W630)
- lib/xaas/semantics/eu_ai_act_admission.ex [M] — W732 (hunk-marked)
- lib/xaas/semantics/robust_margin.ex [M] — W630/W676 (hunk-marked W630)
- lib/xaas/semantics/vulnerability_lifecycle.ex [M] — W732 (hunk-marked)
- lib/xaas/semantics/oversight_governance.ex [M] — W679/W833 (hunk-marked)
- lib/xaas/semantics/incident_report.ex [M] — W679 family (hunk-marker absent, diff review at commit) — VERIFY-AT-COMMIT
- lib/xaas/semantics/computation.ex [M] — W741/W763/W782/W849/W832 — HOLD (multi-lane)
- lib/xaas/semantics/eu_ai_act_admission_test.exs [M] — W732 (hunk-marked)
- test/xaas/semantics/robust_margin_test.exs [M] — W676 (hunk-marked)
- test/xaas/semantics/dataset_admission_test.exs [M] — W676 (hunk-marked)
- test/xaas/semantics/incident_report_test.exs [M] — W679 (hunk-marked)
- test/xaas/semantics/art12_chain_court_test.exs [M] — W503-W539 convergence (hunk-marked) — VERIFY-AT-COMMIT
- test/xaas/semantics/eu_ai_act_refusal_closed_set_test.exs [M] — W732 (hunk-marked)
- test/xaas/semantics/vulnerability_lifecycle_test.exs [M] — W732 (hunk-marked)
## CG-08 · EU-AI-Act deepening tests (untracked, receipt-matched)
Message: test(eu_ai_act): article deepening suites (W665/W667/W669/W696/W710/W692/W706)
- test/eu_ai_act/art15_deepening_test.exs [??] — W667 (receipt)
- test/eu_ai_act/art50_deepening_test.exs [??] — W665 (receipt)
- test/eu_ai_act/art73_chain_deepening_test.exs [??] — W669 (receipt)
- test/eu_ai_act/art86_rights_deepening_test.exs [??] — W710 (receipt)
- test/eu_ai_act/art99_enforcement_deepening_test.exs [??] — W696 (receipt)
- test/eu_ai_act/counterfactual_deepening_test.exs [??] — W692 (receipt)
- test/eu_ai_act/eyerun_wire_deepening_test.exs [??] — W706 (receipt)
- test/eu_ai_act/not_applicable_completeness_test.exs [??] — unattributed — VERIFY-AT-COMMIT
- test/eu_ai_act/title_ii_deepening_test.exs [??] — W691 (receipt)
## CG-09 · Deepening/court tests: xaas_web surface (untracked, receipt-matched)
Message: test(web): surface courts + deepening suites (W745/W699/W751/W723/W743/W813/W805/W817/W802/W836/W829/W837/W774/W725/W776)
- test/xaas_web/a2a_v1_wire_deepening_test.exs [??] — W699/W751
- test/xaas_web/dev_routes_court_test.exs [??] — W774
- test/xaas_web/eu_ai_act_export_deepening_test.exs [??] — W771
- test/xaas_web/health_court_test.exs [??] — W836
- test/xaas_web/json_api_surface_court_test.exs [??] — W805/W849 — VERIFY-AT-COMMIT
- test/xaas_web/jsonapi_content_negotiation_test.exs [??] — W817
- test/xaas_web/mcp_tools_deepening_test.exs [??] — W800
- test/xaas_web/next_read_live_deepening_test.exs [??] — W766
- test/xaas_web/ontop_proxy_deepening_test.exs [??] — W776/W794
- test/xaas_web/plug_mount_order_court_test.exs [??] — W703
- test/xaas_web/quiescent_fabric_tie_test.exs already listed in CG-05 — cross-ref only
- test/xaas_web/require_internal_api_token_deepening_test.exs [??] — W723/W739/W769
- test/xaas_web/resolve_org_actor_deepening_test.exs [??] — W743/W812
- test/xaas_web/rpc_surface_deepening_test.exs [??] — W813
- test/xaas_web/sensitive_resources_routing_court_test.exs [??] — W829
- test/xaas_web/stripe_webhook_deepening_test.exs [??] — W725/W775
- test/xaas_web/ts_codegen_drift_court_test.exs [??] — W837/W849
## CG-10 · Deepening tests: domain deepening (untracked, receipt-matched)
Message: test(domain): deepening suites for governance/library/operations/bridges (W722/W728/W730/W787-W790/W795-W798/W815/W811/W816)
- test/xaas/governance/multitenant_approval_deepening_test.exs [??] — W722/W740/W789
- test/xaas/governance/paper_trail_deepening_test.exs [??] — W788
- test/xaas/governance/security_resources_deepening_test.exs [??] — W769/W812
- test/xaas/library/embedding_deepening_test.exs [??] — W787
- test/xaas/library/nextread_deepening_test.exs [??] — W742
- test/xaas/library/persona_grant_deepening_test.exs [??] — W718
- test/xaas/library/pubsub_publish_court_test.exs [??] — W718/W812 — VERIFY-AT-COMMIT
- test/xaas/conference_deepening_test.exs [??] — W715/W795
- test/xaas/ocel_deepening_test.exs [??] — W721/W758
- test/xaas/telemetry/ocel_egress_deepening_test.exs [??] — W666/W663b
- test/xaas/telemetry/ocel_forwarder_deepening_test.exs [??] — W764
- test/xaas/operations/capability_liveness_deepening_test.exs [??] — W750/W768
- test/xaas/operations/audit_log_deepening_test.exs [??] — W728
- test/xaas/bridges/ferroplan_deepening_test.exs [??] — W716
- test/xaas/bridges/registry_deepening_test.exs = W767 — VERIFY
- test/xaas/bridges/registry_deepening_test.exs [??] — W767
- test/xaas/operations/route_castle_run_surface_test.exs [??] — unattributed — VERIFY-AT-COMMIT
- test/xaas/schema_migration_consistency_test.exs [??] — unattributed — VERIFY-AT-COMMIT
- test/xaas/operations/validations/capability_liveness_receipt_status_gate.ex [??] — W768/W830 — HOLD (multi-lane)
## CG-11 · Deepening tests: remaining lib+domains (untracked)
Message: test(domain): remaining deepening suites — accounts/billing/graphlaw/etc (W727/W729/W731/W733/W734/W735/W736/W744/W748/W780/W814)
- test/xaas/accounts_deepening_test.exs [??] — W727 (receipt: 1-file diff)
- test/xaas/map_update_dual_safe_test.exs [??] — W658d/W659c
- test/xaas/ash_a2a_runtime_config_court_test.exs [??] — W720/W803
- test/xaas/a2a_resources_deepening_test.exs [??] — W751
- test/xaas/sa2a_computation_boundary_test.exs [??] — W763/W780/W782/W861
- test/xaas/actuation/run_idempotency_deepening_test.exs cross-ref CG-05
- test/xaas/graphlaw_deepening_test.exs [??] — W731
- test/xaas/igniter_deepening_test.exs [??] — W734
- test/xaas/marketplace_deepening_test.exs [??] — W733
- test/xaas/coupling_deepening_test.exs [??] — W735
- test/xaas/generation_deepening_test.exs [??] — W736
- test/xaas/zoe_deepening_test.exs [??] — W744
- test/xaas/workbench_deepening_test.exs [??] — W748
- test/xaas/security_deepening_test.exs [??] — W730
- test/xaas/multitenancy_deepening_test.exs [??] — W789
- test/xaas/temporal_memory_deepening_test.exs [??] — W724
- test/xaas/ultracode/run_receipt_deepening_test.exs [??] — W717/W737/W804
- test/xaas/witness/witness_surface_deepening_test.exs [??] — W698/W726
- test/xaas/witness/catalog_durability_test.exs [??] — W709
- test/xaas/wasm4pm_serde_surface_pin_test.exs [??] — W673
- test/xaas/semantics/ferroplan_airo_pin_test.exs [??] — W693
- test/xaas/semantics/declared_metrics_staleness_test.exs [??] — W697
- test/xaas/semantics/refusal_atom_census_test.exs [??] — W713
- test/xaas/semantics/master_equation_composition_stress_test.exs [??] — W719
- test/xaas/operations/gymact_surface_deepening_test.exs cross-ref CG-05
## CG-12 · E2E / playwright surface (W688/W823/W842/W848)
Message: test(e2e): playwright marking + next-read seed + revalidation (W688/W823/W842/W848)
- e2e/a2a-marking.spec.cjs [??] — W688/W842
- e2e/seed-library.exs [??] — W823 (receipt: nextread-seed)
- e2e/global-setup.cjs [M] — W823 (hunk-marked)
- e2e/next-read-ml.spec.cjs [M] — W823 (hunk-marked)
- playwright.config.cjs [M] — W848 (hunk-marked; also W688/W842)
- test/xaas/w838_probe_test.exs [??] — W839-family probe — VERIFY-AT-COMMIT (possibly delete)
- test/w707_tmp/ [dir] — transidirectory — DELETE, do not commit
- test/xaas/ledger/ already in CG-03 — cross-ref
## CG-13 · Docs: diataxis + cro + corpus (W689/W671/W830/W806/W807/W753/W759/W797/W797/W827/W857/W794)
Message: docs: diataxis reference/how-to updates + CRO artifacts (W671/W689/W830/W806/W807/W753/W759/W827/W857)
- docs/claude/diataxis/reference/eu-ai-act-semantics.md [??] — W671/W864
- docs/claude/diataxis/reference/standing-vocabulary.md [??] — W830 (receipt: files-written)
- docs/claude/diataxis/README.md [M] — W830/W671 (hunk context) — VERIFY-AT-COMMIT
- docs/claude/diataxis/explanation/architecture-overview.md [M] — W827 (hunk-marked)
- docs/claude/diataxis/explanation/ash-typescript-adoption.md [M] — W820/W813 (hunk-marked)
- docs/claude/diataxis/explanation/ocel-egress-forwarder.md [M] — W702 (hunk context) — VERIFY-AT-COMMIT
- docs/claude/diataxis/how-to/actuate-provider-lifecycle.md [M] — W712 — VERIFY-AT-COMMIT
- docs/claude/diataxis/how-to/author-ggen-templates-safely.md [M] — W862 (receipt)
- docs/claude/diataxis/how-to/fix-ash-admin-and-use-ggen-for-codegen.md [M] — W841 (receipt)
- docs/claude/diataxis/reference/actuation-and-semantics.md [M] — W712 — VERIFY-AT-COMMIT
- docs/claude/diataxis/reference/ash-configuration.md [M] — W698/W709/W726 (hunk-marked)
- docs/claude/diataxis/reference/generated-castle-bridge-errc.md [M] — W849/W810/W837/W754 (hunk-marked)
- docs/claude/diataxis/reference/sa2a-computation-boundary.md [M] — W763/W714 — VERIFY-AT-COMMIT
- docs/claude/diataxis/reference/ultracode-runtime-contract.md [M] — W723/W745/W747 (hunk-marked)
- docs/eu_ai_act/corpus-README.md [M] — W797 (receipt)
- docs/case-studies/next-read/README.md [M] — W850 (receipt: readme-verify)
- docs/cro/ARTIFACT-MANIFEST.md [M] — W759/W807 — VERIFY-AT-COMMIT
- docs/cro/CRO-LOOP.md [M] — W807 — VERIFY-AT-COMMIT
- docs/cro/CYCLE-LOG.md [M] — W753/W759 — VERIFY-AT-COMMIT
- docs/cro/artifacts/* [M/??] — evidence-claims-index (W711/W855), implementation-wave-ledger (W781), refusal-ledger json (W759), end-user-disclosure (W806), s3-evidence-pack (W861), airo-wiring-ledger + w668 verification (W668/W790)
## CG-14 · Receipts: sjira plans (untracked) — fleet receipts
Message: docs(sjira): v26.10.6 wave receipts w640-w864 (~160 files)
- docs/sjira/v26.10.6/plans/w640..w864 [?? x ~160] — the untracked plan receipt files listed by git status; all COMMIT as one receipts commit (they are read-only evidence).
- docs/sjira/v26.10.6/plans/_INDEX.md [M] — W737/W777 — COMMIT
- docs/sjira/v26.10.6/_CLOSURE_PLAN.md [MM] — W700/W798 — VERIFY-AT-COMMIT
- docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md [M] — W854 — VERIFY-AT-COMMIT
- docs/sjira/v26.10.6/plans/w603, w617, w659b [M] — committed-plan updates — COMMIT
- docs/cro/artifacts/airo-wiring-ledger-verification-w668.md [??] — W668/W790
## HOLD — files not to commit in this pass
- lib/xaas_web/router.ex [M] — hunk markers stale (W739/W150/W299c); current edit unattributed across W774/W800/W802/W813/W817/W836/W861/W862 — coordinator resolves owner before commit.
- lib/xaas/operations/validations/incident_resolved_is_terminal.ex [??] — claimed by W803/W804/W808/W809/W818/W831; hunk-level owner unresolved.
- lib/xaas/ocel.ex [M] — claimed by W738/W741/W742/W743/W744/W745/W747/W748/W758/W762.
- lib/xaas/a2a/validations/ [dir ??] — W772/W784 — split by actual content at commit time; HOLD.
- lib/xaas/ledger/validations/ [dir ??] — W663b/W746/W762/W799 — HOLD.
- lib/xaas/operations/validations/capability_liveness_receipt_status_gate.ex [??] — W768/W830 — HOLD.
- lib/xaas/platform/changes/route_orgs_custom_domain_approve.ex [D] + validations/route_orgs_custom_domain_requires_approver.ex [D] — deletion lane unresolved (W770/W792/W808/W810) — HOLD deletions for operator.
- lib/xaas/platform/changes/route_projects_backups_approve.ex [D] + validations/route_projects_backups_requires_approver.ex [D] — same — HOLD deletions for operator.
- lib/xaas/operations/gymact_surface.ex cross-ref CG-05 (listed once only)
- cleanup-plan.json [??] — transient cleanup-plan — DELETE, do not commit.
- priv/semantic/generated/ [dir ??] — generated surface; commit only via its lawful generator step, not this pass — HOLD.
- docs/claude/diataxis/reference/http-api-surface.md referenced by W836 receipt but not in git status — no-op row, informational only.
## Operator decisions required
1. config/dev.exs (W803): cluster_size 1->3 for AshA2A receipt EKV store — dev-only boot config; confirm dev boot before commit.
2. Migrations W786 (20261007111457) + W804 (20261007120000) touch xaas_dev: W804 dedups orgless epochs (deletes rows) before a unique index; W786 adds logical partitions. Commit only after operator confirms dev-DB migration run.
3. Platform route deletions (route_orgs_custom_domain*, route_projects_backups*) — deletion lane unresolved; confirm intent (W770/W792/W808/W810) before staging deletion.
4. Transients cleanup-plan.json + test/w707_tmp/: delete rather than commit (coordinator confirm).
5. config/test.exs W822 port config: env-driven port is safe but changes CI behavior if PORT/PW_PORT set — confirm CI unaffected.
6. priv/semantic/generated/: if the consolidation wave claims it as generated projection (W663b/W664b receipts mention it), it needs its generator step, not a hand commit — operator call.
7. lib/xaas/semantics/incident_report.ex diff has no W-marker; W679 claims repair — verify diff content at commit time.
## Standing
- Manifest staging: ALIVE (this file, generated from live git status + receipts at HEAD a0723bf6).
- Commit execution: UNKNOWN — coordinator owns git operations; manifest is advisory staging.
- Attribution confidence: hunk-marker/receipt files-written rows = high; name<->receipt matches = medium; VERIFY-AT-COMMIT rows = low (no hunk evidence, no unique receipt claim).
- No git operations performed by lane W867. No build root created.
## CG-15 · Coverage gap-closure rows (post-sweep addition)
- docs/claude/diataxis/explanation/errc-innovation-grid.md [M] — W756 — VERIFY-AT-COMMIT
- docs/claude/diataxis/tutorials/build-an-autonomic-capability-loop.md [M] — unattributed — VERIFY-AT-COMMIT
- docs/claude/diataxis/tutorials/receipted-provider-lifecycle.md [M] — unattributed — VERIFY-AT-COMMIT
- docs/cro/artifacts/airo-wiring-ledger.md [M] — W668/W790 family (see CG-13 blanket row)
- docs/cro/artifacts/end-user-disclosure-v26.10.6.md [M] — W806 (receipt) — in CG-13 blanket row
- docs/cro/artifacts/evidence-claims-index.md [M] — W711/W855 — CG-13 blanket row
- docs/cro/artifacts/implementation-wave-ledger.md [M] — W781 — CG-13 blanket row
- docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json [M] — W759 family — CG-13 blanket row
- docs/cro/artifacts/s3-evidence-pack-v26.10.6.md [M] — W861 (receipt) — CG-13 blanket row
- lib/mix/tasks/xaas.release_audit.ex [M] — W814 (receipt: findings-only run) — VERIFY-AT-COMMIT
- lib/mix/tasks/xaas.doctor.ex [??] — W791/W825 (receipts)
- lib/xaas/a2a/task.ex [M] — W772 (hunk context; also W784) — VERIFY-AT-COMMIT
- lib/xaas/checks/system_actor.ex [M] — unattributed — HOLD
- lib/xaas/conference/registration.ex [M] — W715 (hunk-marked)
- lib/xaas/conference/session.ex [M] — W715 (hunk-marked)
- lib/xaas/operations/capability_liveness_receipt.ex [M] — W768 (hunk-marked)
- lib/xaas/ultracode/epoch.ex [M] — W737 (hunk-marked)
- lib/xaas_web/controllers/health_controller.ex [M] — W836/W860 — VERIFY-AT-COMMIT
- lib/xaas/platform/validations/route_orgs_custom_domain_requires_approver.ex [D] — HOLD (see HOLD deletions)
- lib/xaas/platform/validations/route_projects_backups_requires_approver.ex [D] — HOLD (see HOLD deletions)
- test/eu_ai_act/airo_grounding_test.exs [M] — W657/W702/W732 (hunk-marked W732)
- test/eu_ai_act/counterfactual_test.exs [M] — W637b/W694 convergence — VERIFY-AT-COMMIT
- test/eu_ai_act/title_i_test.exs [M] — W732/W679/W861 — VERIFY-AT-COMMIT
- test/eu_ai_act/title_ii_test.exs [M] — W732 — VERIFY-AT-COMMIT
- test/eu_ai_act/title_iii_test.exs [M] — W540/W816 — VERIFY-AT-COMMIT
- test/eu_ai_act/title_iv_v_test.exs — W732/W779 — VERIFY-AT-COMMIT
- test/eu_ai_act/title_vi_xiii_test.exs [M] — W708 (hunk-marked)
- test/xaas/accounts/token_revocation_test.exs [M] — W727/W786 (hunk-marked; W786 pin flip)
- test/xaas/generated/registry_drift_guard_test.exs [M] — W852/W849 — VERIFY-AT-COMMIT
- test/xaas/semantics/airo_risk_mapping_test.exs [M] — W657/W668/W702 — VERIFY-AT-COMMIT
- test/xaas/semantics/eu_ai_act_admission_test.exs [M] — W732 (hunk-marked)
- test/xaas/semantics/jcs_property_test.exs [M] — W641/W645c family — VERIFY-AT-COMMIT
- test/xaas/ontology/staleness_task_court_test.exs [??] — W697/W694 — VERIFY-AT-COMMIT
- test/xaas/sa2a_bridge_deepening_test.exs [??] — W741 (name-receipt)
- test/xaas/semantics/computation_doctest_test.exs [??] — W832 (name-receipt)
- docs/sjira/v26.10.6/_COMMIT_MANIFEST_W850.md [??] — this manifest, lane W867 — COMMIT (or hold to next pass, operator)

## Adjudication (W875)

Evidence method: per HOLD path, `git diff HEAD -- <path>` (or file content for
untracked files) matched against the Files-written sections of candidate-lane
receipts at HEAD a0723bf6. No git operations, no build root. Original groups
above are unchanged; coordinator re-groups.

| HOLD path | Evidence (diff/content vs receipt) | Owner | Proposal |
|---|---|---|---|
| lib/xaas_web/router.ex [M] | Hunk is the pipeline reorder (`:require_internal_api_token` first) + a comment self-marked W739 ("same class as W150/W299c"); byte-matches `plans/w739-406-leak-fix.md` Fix section exactly. W867's candidate list (W774/W800/...) was wrong — the marker is in-hunk. | W739 | COMMIT — group with W739 (router + `test/xaas_web/require_internal_api_token_deepening_test.exs`) |
| lib/xaas/operations/validations/incident_resolved_is_terminal.ex [??] | Content matches W818's described guard (b): `changeset.data` + `Ash.Changeset.get_attribute/2` house idiom (W818 documents removing the nonexistent `Ash.Changeset.OriginalDataNotLoaded` — absent here), terminal-reopen message verbatim in receipt's class. Sibling claims (W803/W804/W808/W809/W831) do not list this file in any Files-written section; they reference it read-only or via its wiring in `incident.ex`. | W818 | COMMIT — CG-05 (with `incident.ex` guard wiring + the two incident test files, W818's artifact list) |
| lib/xaas/ocel.ex [M] | Single hunk = `fold_object_state/2` public fold; matches `plans/w758-ocel-fold.md` ("Files touched (only): lib/xaas/ocel.ex, test/xaas/ocel_deepening_test.exs"). W741's receipt explicitly disclaims ocel.ex ("a sibling lane's in-flight edit ... not this lane's file"); W745's only claim is the `::` spec repair folded into W758. | W758 | COMMIT — group with W758 (ocel.ex + ocel_deepening_test.exs) |
| lib/xaas/a2a/validations/forward_only_transition.ex [??] | Sole file in the dir; `plans/w772-a2a-transition-guard.md` claims it as "new ... the guard" with "No other files touched". W784 references it read-only (closest-neighbor scan table). | W772 | COMMIT — group with W772 |
| lib/xaas/ledger/validations/transfer_source_sufficiency.ex [??] | Sole file in the dir; `plans/w762-transfer-sufficiency.md` claims it as item 1 of its diff. W746/W799/W663b do not claim it. | W762 | COMMIT — group with W762 |
| lib/xaas/operations/validations/capability_liveness_receipt_status_gate.ex [??] | `plans/w768-liveness-alive-gate.md` claims it as new file 1 of its 3-file diff; W830 only read it (receipt lists it under Sources read). | W768 | COMMIT — group with W768 |
| lib/xaas/platform/changes/route_orgs_custom_domain_approve.ex [D] + validations/route_orgs_custom_domain_requires_approver.ex [D] | W792 receipt: "Typed deletion (2 of 5 pairs)" — resources carry no approver metadata columns (verified against initial migration); court test (6d) pins the deletion. Intentional, receipted deletion. | W792 | OPERATOR — owner resolved (W792, intentional + court-pinned); operator confirms intent and stages with the W792 group |
| lib/xaas/platform/changes/route_projects_backups_approve.ex [D] + validations/route_projects_backups_requires_approver.ex [D] | Same W792 deletion pair, same rationale + court (6d). | W792 | OPERATOR — same |
| lib/xaas/checks/system_actor.ex [M] | Diff adds `{RouteSecrets,:approve}`, `{RouteProjects,:approve}`, `{RouteFeatureFlags,:approve}` to `@internal_api_actions` — exactly W792's approver wiring (receipt names system_actor.ex's exact-subject allowlist; tests court `Ash.Error.Forbidden` for non-system actors). | W792 | COMMIT — group with W792 |
| priv/semantic/generated/ [??] | Generated projection surface (castle_bridge_shacl.ttl, MANIFEST.json); manifest HOLD law: commit only via its lawful generator step. | — | OPERATOR — unchanged; regenerate via generator step, never hand-commit |

Summary: 7 COMMIT proposals (W739, W818/CG-05, W758, W772, W762, W768, W792
system_actor.ex), 2 OPERATOR deletion pairs (owner resolved to W792's
receipted deletion), 1 OPERATOR generated dir. Zero HOLD-for-lane rows — all
owner lanes have landed receipts; no still-running owner exists.

## Final (W881) — reconciliation

Appended by lane W881, 2026-10-07, at /Users/sac/xaas @ feat/playwright-surface
(HEAD a0723bf6). Folds W875's adjudication
(`plans/w875-hold-adjudication.md`) into this manifest as the final actionable
staging state. No git operations, no build root. Coordinator executes only
after every pre-commit check below is LANDED **and** an explicit user commit
instruction is given.

### (a) 15 groups, adjudicated paths merged

All CG-01..CG-15 group compositions from the W867 staging (above) carry
forward unchanged, with these W875-adjudicated merges applied:

| Adjudicated path | Was | Final owner / group |
|---|---|---|
| lib/xaas_web/router.ex [M] | HOLD | **W739** — commit paired with `test/xaas_web/require_internal_api_token_deepening_test.exs` (CG-09 row) as the W739 group |
| lib/xaas/operations/validations/incident_resolved_is_terminal.ex [??] | HOLD | **W818 → CG-05** (with incident.ex wiring + incident_test.exs + incident_lifecycle_deepening_test.exs) |
| lib/xaas/ocel.ex [M] | HOLD | **W758** — with `test/xaas/ocel_deepening_test.exs` (CG-10 row) as the W758 group |
| lib/xaas/a2a/validations/forward_only_transition.ex [??] | HOLD | **W772** — with `lib/xaas/a2a/task.ex` (CG-15 row, W772 hunk context) as the W772 group |
| lib/xaas/ledger/validations/transfer_source_sufficiency.ex [??] | HOLD | **W762 → CG-03** (ledger/validations dir resolved to its sole file) |
| lib/xaas/operations/validations/capability_liveness_receipt_status_gate.ex [??] | HOLD | **W768** — with `lib/xaas/operations/capability_liveness_receipt.ex` + `test/xaas/operations/capability_liveness_deepening_test.exs` as the W768 group |
| lib/xaas/checks/system_actor.ex [M] | HOLD (unattributed) | **W792 → CG-06** (approver wiring allowlist additions, receipt-named) |
| lib/xaas/platform/changes/route_orgs_custom_domain_approve.ex [D] + validations/route_orgs_custom_domain_requires_approver.ex [D] | HOLD | **OPERATOR** (owner = W792 receipted deletion; operator confirms intent, stages with CG-06/W792) |
| lib/xaas/platform/changes/route_projects_backups_approve.ex [D] + validations/route_projects_backups_requires_approver.ex [D] | HOLD | **OPERATOR** (same W792 deletion pair class; operator confirms intent, stages with CG-06/W792) |
| priv/semantic/generated/ [??] | HOLD | **OPERATOR** — generated projection surface (castle_bridge_shacl.ttl, MANIFEST.json); commit only via its lawful generator step, never hand-commit |
| lib/xaas/semantics/computation.ex [M] (CG-07 HOLD) | HOLD | unchanged: multi-lane — VERIFY-AT-COMMIT by hunk at commit time |

Zero HOLD-for-lane rows remain: every owner lane has a landed receipt at
HEAD a0723bf6 (W881 test -f sweep, 2026-10-07).

### (b) OPERATOR section — reduced to exactly 3 rows

1. **Deletion-pair staging confirmation.** The 2 platform deletion pairs
   (`route_orgs_custom_domain_approve.ex` + `_requires_approver.ex`,
   `route_projects_backups_approve.ex` + `_requires_approver.ex`) are W792's
   receipted, court-pinned deletion (2 of 5 pairs). Operator confirms intent;
   coordinator stages them with the CG-06/W792 group.
2. **priv/semantic/generated/ generator step.** Generated projection surface;
   do not hand-commit. Either run its lawful generator step and commit the
   projection, or leave uncommitted this pass. Operator call.
3. **W786/W804 dev migrate.** Run `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=dev
   mix ecto.migrate` on `xaas_dev` (W786 logical-partition migration
   20261007111457; W804 dedup+unique-index migration 20261007120000, which
   deletes dup rows — keep-rule: earliest inserted_at, smallest id) before
   committing CG-01's migration files.

(Supersedes W867's 7-row operator-decision list; the other 4 decisions are
resolved by this reconciliation: transients (cleanup-plan.json,
test/w707_tmp/) = delete, do not commit; test.exs W822 env port = commit
(CG-01); incident_report.ex = W679, VERIFY-AT-COMMIT at commit;
cluster_size 1->3 in dev.exs = commit with CG-01 under W803's receipt.)

### (c) Pre-commit checklist

| Check | Receipt | State |
|---|---|---|
| Census certified | plans/w821-terminal-census-2.md | **LANDED** (on disk) |
| Gate green | plans/w778-gate-fix-verify.md | **LANDED** (on disk) |
| Priority e2e | plans/w842-e2e-revalidation.md | **LANDED** (on disk) |
| Doctor statuses | plans/w847-doctor-recal.md | **LANDED** (on disk) |
| ~17 in-flight lanes (W810-W826 wave) | plans/w810..w826-*.md | **LANDED** — all 17 receipts test -f verified on disk 2026-10-07 (w810-route-surface, w811-lease-kernel-deepening, w812-org-resolution-coverage, w813-rpc-surface-deepening, w814-release-audit-run, w815-gap-registration, w816-155s3-residual, w817-negotiation-court, w818-incident-guards, w819-graphql-doc-fix, w820-ts-adoption-verify, w821-terminal-census-2, w822-port-config, w823-nextread-seed, w824-quiescent-fabric-tie, w825-doctor-tune, w826-closure-gates-verify) |
| W875 adjudication | plans/w875-hold-adjudication.md | **LANDED** (folded into this section) |
| W878 lease census | plans/w878-*.md | **PENDING** — not on disk; gates only the operator lease-cleanup step (#1 of the runbook sequence), NOT the commit gate; coordinator deletes lane build roots only after per-lane receipts (all landed) |
| Explicit user commit instruction | — | **PENDING** — required before coordinator executes any git op |

### (d) Totals (real, at W881 time, 2026-10-07)

- `git diff HEAD --stat` tail: **112 files changed, 3213 insertions(+), 458 deletions(-)** (tracked changes).
- `git status --porcelain`: **440 entries** = 328 untracked (`??`) + 98 modified (`M`) + 10 modified-staged (`MM`) + 4 deleted (`D`).
- Combined staging surface: **440 working-tree entries** (328 untracked + 112 tracked-changed).
- CG-14 receipt blanket covers the sjira `plans/` untracked receipts.

### Standing

- Manifest (final, W881): **ALIVE** as staging — every path grounded in live
  git status + W875's diff/receipt-match adjudication at a0723bf6.
- Commit execution: **UNKNOWN** — coordinator-owned; blocked on the two
  PENDING checklist rows (W878 is operator-gated, not commit-gated; explicit
  user commit instruction not yet given).
- No git operations performed by lane W881. No build root created.

## Manifest addendum (W889b, post-W885 precheck)

Resolves W885 finding (a) (`plans/w885-final-gate-precheck.md`): 5 working-tree paths
named nowhere in the manifest's CG rows, all post-W881 lanes. Verified live at
`feat/playwright-surface` @ a0723bf6, 2026-10-07, lane W889b (`git status --porcelain`
per path; owner receipt greps against `plans/*.md`).

| # | Path (live status) | Owner receipt | Verified named in receipt | Proposed group |
|---|---|---|---|---|
| 1 | `lib/xaas/semantics/dataset_admission.ex` [M] | `plans/w865-gap3-fix.md` (W865, LANDED) | YES | **CG-07** (semantics lib; its test `dataset_admission_test.exs` is already CG-07) |
| 2 | `lib/xaas/semantics/jcs.ex` [M] | `plans/w851-jcs-doctests.md` (W851, LANDED) | YES | **CG-07** |
| 3 | `test/xaas/semantics/jcs_doctest_test.exs` [??] | `plans/w851-jcs-doctests.md` (W851, LANDED) | YES | **CG-07** |
| 4 | `test/xaas/ledger/reversal_deepening_test.exs` [??, sole file in untracked `test/xaas/ledger/`] | `plans/w799-reversal-deepening.md` (W799, LANDED) | YES | **CG-03** (CG-03 already carries the dir row `test/xaas/ledger/ [dir ??] — W799/W835 — enumerate contents at commit time`; this row pins the sole file) |
| 5 | `test/xaas/release_audit_enoent_court_test.exs` [?? → COMMITTED @ 51150f4c] | ~~IN_FLIGHT / UNCLAIMED~~ → **RESOLVED (W964, 2026-10-07)**: owner = `plans/w873-enoent-court.md` (W873, LANDED — names the test file, 4/4 solo + 8/8 joint, standing ALIVE) + `plans/w896b-court-fix.md` (court-shape fixes — wrapped-REFUSED extraction + OS-19 `@version` scan exemption; final green 4/4). Ownership trail: `w896-enoent-court-owner.md` (retroactive provenance) → w873 → w896b. This row's "w873 receipt does NOT exist" premise was true at write time, superseded by its own addendum in `w896-enoent-court-owner.md`. | YES | **CG-14-adjacent court test (COMMIT)** — committed in W940's CG-14 blanket commit 51150f4c (`git log --oneline -- <path>` verified by W964) |

Note: the task's "W845/W873's file" disambiguation resolves to W845-by-subject;
W873 has no receipt on disk. This row stays IN_FLIGHT until a receipt naming
`test/xaas/release_audit_enoent_court_test.exs` lands or the coordinator admits the
W845-subject match.

Receipt pointers (W898, 2026-10-07, `plans/w898-residue-backfill.md`):
(1) `test/xaas/ontology/staleness_task_court_test.exs` [??] is now **COVERED** by
`plans/w869-staleness-court.md` (LANDED, ALIVE, 7 tests, names the exact path
as its sole new file) — manifest row "W697/W694 — VERIFY-AT-COMMIT" resolves
to W869. (2) Addendum row 5 (`release_audit_enoent_court_test.exs`): no
`w873-*.md` has landed (re-verified, 688 receipt files); ownership
backfill note recorded in `plans/w898-residue-backfill.md` §Item 2 — the
court's moduledoc and asserted finding strings are literally W845's
(`plans/w845-audit-enoent.md` §2), coordinator to admit the W845-subject
match or hold per this row's own terms.

## Census row resolution (W889b)

The Final (W881) checklist row "W878 lease census — **PENDING** — not on disk" resolves
to **LANDED**: `plans/w878-lease-census.md` is on disk (test -f OK, W885 confirmed,
re-confirmed W889b). Census actuals per the receipt: 68 xaas `_build-lane*` dirs /
28.21 GB measured; **deletable grand total 81 entries / ~31.03 GB** (66 xaas receipt-
backed ~27.33 GB + 9 sibling-repo ~3.19 GB + 6 /tmp lease dirs ~0.51 GB); CHECK: W856,
W865 (~0.86 GB); KEEP: W880 (in-flight at census time). (W885's summary quoted
"~28.57 GB / 73 lease dirs" — that is W885's live-rollup figure, not the receipt's own
totals; recorded here to prevent number drift.) Gates only the operator lease-cleanup
step, not the commit gate. Remaining PENDING: explicit user commit instruction only.
