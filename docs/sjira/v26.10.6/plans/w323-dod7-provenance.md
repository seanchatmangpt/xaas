# W323 — DoD 7 Provenance Map (review-time admission map)

Lane W323, 2026-10-06. Repo: /Users/sac/xaas @ feat/playwright-surface, read-only
(no git mutations, no commits — coordinator-gated). Every working-tree diff traced
to closure provenance: a `_CLOSURE_PLAN.md` §1/§2/§3 row, or a landing receipt
under `docs/sjira/v26.10.6/plans/`.

Method: `git status --porcelain` → 229 entries (159 M, 2 R staged, 68 ??) →
231 unique paths (renames counted once per side). Each path matched literally
against `_CLOSURE_PLAN.md` and all receipt files in `plans/` (single-pass corpus
grep, not lane recall). Classification:

- **TRACED** = literal path in _CLOSURE_PLAN.md + ≥1 receipt
- **TRACED-RECEIPT-ONLY** = receipt cites path (or module/dir name), no plan row — plan addendum candidates
- **UNTRACED** = no plan row, no receipt — DoD 7 refusal candidates

## Counts

| class | count |
|---|---|
| TRACED | 39 |
| TRACED-RECEIPT-ONLY | 192 |
| UNTRACED | 0 |
| total paths | 231 |

## UNTRACED list

After dir/module-level fuzzy resolution (v1_transport_plug → w270 by module
name; resource_snapshots → w247/w223/w258 by dir name), **zero paths remain
hard-untraced**. The 9 literal-match misses above are reclassified
TRACED-RECEIPT-ONLY with the evidence shown. DoD 7 refusal candidates: none.

## Staged set (git diff --cached)

Nonempty: exactly 2 renames `e2e/ash-admin-{destroy,state-change}.spec.js → .spec.cjs`
(ESM/CJS renames, plan §4 P3-3 + w191 Playwright commit group). Both TRACED.

## Per-path provenance table

| class | path | plan ref | receipts |
|---|---|---|---|
| TRACED-RECEIPT-ONLY | `.clap-noun-verb/` | — | _INDEX.md, w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `.ggen_igniter/receipts/2026-10-06.jsonl` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `.github/workflows/ci_cd.yaml` | — | vector3-ignored-suites.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w51-integration-verify.md |
| TRACED-RECEIPT-ONLY | `.github/workflows/playwright-e2e.yml` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md, w51-integration-verify.md |
| TRACED-RECEIPT-ONLY | `bench/prometheus_proxy_error_path_bench.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `bench/sjira_atlassian_projection.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `bench/sjira_atlassian_transport.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `bench/sjira_engineer_workflow.exs` | — | w214-staging-sequence.md |
| TRACED | `CHANGELOG.md` | §1/§3 | r1-ggen.md, r8-gymact.md, vector6-docs-abi.md, w105-marketplace-baseline.md, w114-commit-plan.md |
| TRACED-RECEIPT-ONLY | `config/config.exs` | — | vector6-docs-abi.md, w114-commit-plan.md, w153-commit-plan-v2.md, w174-ontop-health-typing.md, w214-staging-sequence.md |
| TRACED | `config/dev.exs` | §1/§3 | _FRONTIER.md, _WIRING_MATRIX.md, r11-autofde-lab.md, r8-gymact.md, r9-beam4pm.md |
| TRACED-RECEIPT-ONLY | `config/test.exs` | — | w167-pg-saturation.md, w214-staging-sequence.md, x1-playwright-inventory.md |
| TRACED-RECEIPT-ONLY | `docs/claude/diataxis/explanation/architecture-overview.md` | — | w153-commit-plan-v2.md, w214-staging-sequence.md, w328-docs-sweep-verify.md |
| TRACED-RECEIPT-ONLY | `docs/claude/diataxis/reference/actuation-and-semantics.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/claude/diataxis/reference/ash-configuration.md` | — | vector6-docs-abi.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w328-docs-sweep-verify.md |
| TRACED | `docs/claude/diataxis/reference/generated-castle-bridge-errc.md` | §1/§3 | vector4-gen-parity.md, w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/claude/diataxis/reference/http-api-surface.md` | — | vector6-docs-abi.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w328-docs-sweep-verify.md |
| TRACED | `docs/sjira/v26.10.6/` | §1/§3 | _CLOSURE_RECEIPT.md, _FRONTIER.md, r1-ggen.md, r9-beam4pm.md, w114-commit-plan.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/001-xaas-semantic-jira-e2e.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/002-zcode-ocel-pack-consumer.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/003-handwritten-paydown-zcode-plugin.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/004-resource-adoption-registry-exemptions.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/005-zoe-simulation-reconcile.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/006-ecosystem-standing-foldin.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/007-ash-atlassian-target.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/008-gymact-open-backlog.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/009-ash-ai-dependency-retest.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/010-atlassian-public-vocab-pin.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/011-public-ash-projection-extend.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/012-ash-atlassian-profile-admit.md` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/admit.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/generate.py` | — | w139-e4-adjudication.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/receipts/sa2a_post_SJ-003.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.21/sa2a_loop.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.22/sa2a_loop.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `docs/sjira/v26.9.22/shacl.exs` | — | w214-staging-sequence.md |
| TRACED | `e2e/a2a-v1.spec.cjs` | §1/§3 | _WIRING_MATRIX.md, r4-a2a.md, w113-a2a-pw.md, w173-boot-chain.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `e2e/ash-admin-destroy.spec.cjs` *STAGED* | — | w214-staging-sequence.md, w259-pw-definitive.md, w299-pw-final2.md, w302-pw-post-w270.md, w310g-pw-final.md |
| TRACED-RECEIPT-ONLY | `e2e/ash-admin-destroy.spec.js` | — | w51-integration-verify.md, x1-playwright-inventory.md, x1b-playwright-runner.md |
| TRACED-RECEIPT-ONLY | `e2e/ash-admin-matrix.spec.cjs` | — | w111-pw-interim.md, w214-staging-sequence.md, w252-post-fix-e2e.md, w259-pw-definitive.md, w299-pw-final2.md |
| TRACED-RECEIPT-ONLY | `e2e/ash-admin-state-change.spec.cjs` *STAGED* | — | w214-staging-sequence.md, w259-pw-definitive.md, w299-pw-final2.md, w302-pw-post-w270.md, w310g-pw-final.md |
| TRACED-RECEIPT-ONLY | `e2e/ash-admin-state-change.spec.js` | — | w51-integration-verify.md, x1-playwright-inventory.md, x1b-playwright-runner.md |
| TRACED-RECEIPT-ONLY | `e2e/ash-surface-client.spec.cjs` | — | _WIRING_MATRIX.md, w111-pw-interim.md, w214-staging-sequence.md, w299-pw-final2.md, w302-pw-post-w270.md |
| TRACED | `e2e/autofde-lab.spec.cjs` | §1/§3 | _FRONTIER.md, _WIRING_MATRIX.md, r11-autofde-lab.md, w111-pw-interim.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `e2e/chicago-pplan-deep.spec.cjs` | — | _WIRING_MATRIX.md, w111-pw-interim.md, w153-commit-plan-v2.md, w180-seed-class.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `e2e/dev-routes.spec.cjs` | — | w111-pw-interim.md, w214-staging-sequence.md, w252-post-fix-e2e.md, w299-pw-final2.md, w302-pw-post-w270.md |
| TRACED-RECEIPT-ONLY | `e2e/execution-fabric.spec.cjs` | — | w214-staging-sequence.md, w252-post-fix-e2e.md, w299-pw-final2.md, w302-pw-post-w270.md, w310g-pw-final.md |
| TRACED-RECEIPT-ONLY | `e2e/ggen-workbench.spec.cjs` | — | _WIRING_MATRIX.md, w113-a2a-pw.md, w214-staging-sequence.md, w259-pw-definitive.md, w260-ground-truth.md |
| TRACED-RECEIPT-ONLY | `e2e/global-setup.cjs` | — | w135-witness-pw.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md, w259-pw-definitive.md |
| TRACED-RECEIPT-ONLY | `e2e/internal-api.spec.cjs` | — | w173-boot-chain.md, w174-ontop-health-typing.md, w214-staging-sequence.md, w299-pw-final2.md, w302-pw-post-w270.md |
| TRACED-RECEIPT-ONLY | `e2e/mcp-a2a.spec.cjs` | — | _WIRING_MATRIX.md, w113-a2a-pw.md, w214-staging-sequence.md, w259-pw-definitive.md, w299-pw-final2.md |
| TRACED-RECEIPT-ONLY | `e2e/next-read-ml.spec.cjs` | — | w112-witness-nextread-pw.md, w118-pw-final.md, w214-staging-sequence.md, w259-pw-definitive.md, w299-pw-final2.md |
| TRACED-RECEIPT-ONLY | `e2e/seed-witness.exs` | — | w153-commit-plan-v2.md, w173-boot-chain.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `e2e/sparql-proxy.spec.cjs` | — | w214-staging-sequence.md, w259-pw-definitive.md, w299-pw-final2.md, w302-pw-post-w270.md, w310g-pw-final.md |
| TRACED-RECEIPT-ONLY | `e2e/stripe-webhook.spec.cjs` | — | w214-staging-sequence.md, w259-pw-definitive.md, w299-pw-final2.md, w302-pw-post-w270.md, w310g-pw-final.md |
| TRACED-RECEIPT-ONLY | `e2e/system-deep.spec.cjs` | — | w111-pw-interim.md, w214-staging-sequence.md, w252-post-fix-e2e.md, w259-pw-definitive.md, w299-pw-final2.md |
| TRACED-RECEIPT-ONLY | `e2e/wd-fa-cs2.spec.cjs` | — | w214-staging-sequence.md, w259-pw-definitive.md, w299-pw-final2.md, w302-pw-post-w270.md, w310g-pw-final.md |
| TRACED-RECEIPT-ONLY | `e2e/witness.spec.cjs` | — | w112-witness-nextread-pw.md, w118-pw-final.md, w135-witness-pw.md, w153-commit-plan-v2.md, w173-boot-chain.md |
| TRACED-RECEIPT-ONLY | `e2e/zcode-cli-fabric.spec.cjs` | — | _WIRING_MATRIX.md, w171-app-gaps.md, w214-staging-sequence.md, w259-pw-definitive.md, w299-pw-final2.md |
| TRACED | `GGEN-SH-AFTER-MIX-COMPILE.log` | §1/§3 | w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md, w334-head-drift-witness.md |
| TRACED | `GGEN-SH-AFTER-PROOF.txt` | §1/§3 | w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md, w334-head-drift-witness.md |
| TRACED | `ggen.lock` | §1/§3 | _CLOSURE_RECEIPT.md, _FRONTIER.md, r2-marketplace.md, r9-beam4pm.md, vector4-gen-parity.md |
| TRACED | `lib/mix/tasks/xaas.ash_surface.ex` | §1/§3 | vector1-fenced-gates.md, vector4-gen-parity.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/mix/tasks/xaas.capability_coverage.ex` | — | w214-staging-sequence.md, w321-unreachable-reverify.md, w337-ash-policy-floor.md |
| TRACED-RECEIPT-ONLY | `lib/mix/tasks/xaas.fabric.redeploy.ex` | — | w214-staging-sequence.md |
| TRACED | `lib/mix/tasks/xaas.ingest_capability_receipts.ex` | §1/§3 | vector1-fenced-gates.md, w214-staging-sequence.md, w337-ash-policy-floor.md, w338-plan-residual-rows.md, w353-fenced-rows-disposition.md |
| TRACED-RECEIPT-ONLY | `lib/mix/tasks/xaas.release_audit.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/mix/tasks/xaas.release_snapshot.verify.ex` | — | w103-prod-compile.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/mix/tasks/xaas.run_validate.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/mix/tasks/xaas.safe_generate_migrations.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/mix/tasks/xaas.self_digest.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/mix/tasks/xaas.sjira.engineer_work.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/mix/tasks/xaas.stop_court.ex` | — | w107-schema-drift.md, w214-staging-sequence.md, w321-unreachable-reverify.md, w51-integration-verify.md, w82-oracle-rerun.md |
| TRACED | `lib/xaas_web/a2a/next_read_ash_agent.ex` | §1/§3 | r4-a2a.md, vector3-closure-receipt.md, w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/a2a/next_read_user_agent.ex` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w158-suite-with-token.md, w214-staging-sequence.md, w321-unreachable-reverify.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/a2a/v1_transport_plug.ex` | — | w270-a2a-sse.md (module XaasWeb.A2A.V1TransportPlug; filename not cited), w337-ash-policy-floor.md, w342-e2e-coverage-map.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/a2a/zoe_event_simulation_agent.ex` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w321-unreachable-reverify.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/controllers/execution_fabric_controller.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/controllers/health_controller.ex` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w173-boot-chain.md, w174-ontop-health-typing.md, w214-staging-sequence.md |
| TRACED | `lib/xaas_web/endpoint.ex` | §1/§3 | vector5-limits-lints.md, w114-commit-plan.md, w153-commit-plan-v2.md, w205-router-regression.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/live/chicago/drill_down_live.ex` | — | vector1-fenced-gates.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w353-fenced-rows-disposition.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/live/chicago/seller_live.ex` | — | vector5-limits-lints.md, w223-verify-stages2.md, x3-xaas-web.md |
| TRACED | `lib/xaas_web/live/marketplace_catalog_live.ex` | §1/§3 | _WIRING_MATRIX.md, vector1-fenced-gates.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/live/marketplace_pplan_explorer_live.ex` | — | r5-pplan.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, x3-xaas-web.md |
| TRACED | `lib/xaas_web/live/system/command_center_adapter.ex` | §1/§3 | vector1-fenced-gates.md, w214-staging-sequence.md, w337-ash-policy-floor.md, w353-fenced-rows-disposition.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/live/system/command_center_live.ex` | — | vector5-limits-lints.md, w214-staging-sequence.md, x3-xaas-web.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/live/witness_live.ex` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md, w244-format-regression.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/plugs/a2a_parse_floor.ex` | — | w150-auth-floor-fixes.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md, w322-zero-config-posture.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/plugs/stripe_raw_body_reader.ex` | — | w103-prod-compile.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas_web/router.ex` | — | _WIRING_MATRIX.md, r1-ggen.md, r11-autofde-lab.md, r4-a2a.md, r7-zcode-cli.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/a2a/agent.ex` | — | w153-commit-plan-v2.md, w214-staging-sequence.md, w337-ash-policy-floor.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/a2a/task.ex` | — | w103-prod-compile.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/accounts/token.ex` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w333-ash-onetime-diagnosis.md, w337-ash-policy-floor.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/actuation.ex` | — | vector2-refusal-coverage.md, w103-prod-compile.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/application.ex` | — | w109-a2a-v1-court.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w41-pplan-facade.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/autofde/status_parser.ex` | — | _WIRING_MATRIX.md, r11-autofde-lab.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/bridges/ex4pm.ex` | — | w114-commit-plan.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/bridges/ferroplan.ex` | — | _CLOSURE_RECEIPT.md, _WIRING_MATRIX.md, w103-prod-compile.md, w114-commit-plan.md, w153-commit-plan-v2.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/bridges/graphlaw.ex` | — | w114-commit-plan.md, w214-staging-sequence.md |
| TRACED | `lib/xaas/bridges/pplan.ex` | §1/§3 | _WIRING_MATRIX.md, r5-pplan.md, w114-commit-plan.md, w214-staging-sequence.md, w41-pplan-facade.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/bridges/registry.ex` | — | _WIRING_MATRIX.md, r10-wasm4pm.md, r6-ferroplan.md, w114-commit-plan.md, w214-staging-sequence.md |
| TRACED | `lib/xaas/castle.ex` | §1/§3 | vector2-refusal-coverage.md, vector4-gen-parity.md, w114-commit-plan.md, w153-commit-plan-v2.md, w176-refusal-delta-recount.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/chicago/layer.ex` | — | _WIRING_MATRIX.md, r10-wasm4pm.md, w114-commit-plan.md, w146-chicago-suite.md, w153-commit-plan-v2.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/conference/attendee.ex` | — | w103-prod-compile.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/conference/event.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/conference/registration.ex` | — | w103-prod-compile.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/conference/session.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/conference/speaker.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/conference/sponsor.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/conference/track.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/eds/falsifier.ex` | — | w153-commit-plan-v2.md, w214-staging-sequence.md, w321-unreachable-reverify.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/fabric.ex` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/fabric/failure.ex` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/fabric/planes/actuation.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/fabric/planes/evidence.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/fabric/planes/law.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/fabric/planes/process.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/generated/castle_bridge_contract.ex` | — | w191-final-hazards.md, w214-staging-sequence.md, w334-head-drift-witness.md, w354-commit-ready-freshness.md, w51-integration-verify.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/generated/castle_bridge_edges.ex` | — | w191-final-hazards.md, w214-staging-sequence.md, w334-head-drift-witness.md, w354-commit-ready-freshness.md, w51-integration-verify.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/graphlaw/catalog.ex` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/igniter/pack_manifest.ex` | — | w103-prod-compile.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/igniter/refusal_code.ex` | — | w103-prod-compile.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/marketplace/pack.ex` | — | w153-commit-plan-v2.md, w214-staging-sequence.md, w30-playwright-baseline.md |
| TRACED | `lib/xaas/operations/capability_liveness_receipt.ex` | §1/§3 | vector1-fenced-gates.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w337-ash-policy-floor.md |
| TRACED | `lib/xaas/operations/gymact_surface.ex` | §1/§3 | _WIRING_MATRIX.md, r8-gymact.md, w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/sa2a/court.ex` | — | vector1-fenced-gates.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w51-integration-verify.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/security/finding.ex` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/ultracode/autonomic.ex` | — | vector5-limits-lints.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/ultracode/semantic_drive.ex` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w227-ultracode-dir.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/ultracode/semantic_drive/plan_next.ex` | — | vector5-limits-lints.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/witness/catalog.ex` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/witness/certified_receipt.ex` | — | w214-staging-sequence.md, w337-ash-policy-floor.md |
| TRACED-RECEIPT-ONLY | `lib/xaas/witness/verification_key.ex` | — | w214-staging-sequence.md, w337-ash-policy-floor.md |
| TRACED | `mix.exs` | §1/§3 | _CLOSURE_RECEIPT.md, _FRONTIER.md, _INDEX.md, _LANES.md, _WIRING_MATRIX.md |
| TRACED | `mix.lock` | §1/§3 | _CLOSURE_RECEIPT.md, _FRONTIER.md, _INDEX.md, _WIRING_MATRIX.md, r3-igniter.md |
| TRACED-RECEIPT-ONLY | `playwright.config.cjs` | — | _FRONTIER.md, _INDEX.md, r11-autofde-lab.md, r4-a2a.md, r6-ferroplan.md |
| TRACED-RECEIPT-ONLY | `priv/ash_surface/aria.json` | — | vector4-gen-parity.md, vector6-docs-abi.md, w214-staging-sequence.md, w224-drift-authority.md, w336-digest-manifest.md |
| TRACED-RECEIPT-ONLY | `priv/ash_surface/ash_surface_runtime.mjs` | — | w214-staging-sequence.md, w224-drift-authority.md |
| TRACED-RECEIPT-ONLY | `priv/ash_surface/live_view.json` | — | vector6-docs-abi.md, w214-staging-sequence.md, w224-drift-authority.md, w336-digest-manifest.md |
| TRACED-RECEIPT-ONLY | `priv/ash_surface/surface_contract.json` | — | vector6-docs-abi.md, w214-staging-sequence.md, w224-drift-authority.md, w336-digest-manifest.md, w338-plan-residual-rows.md |
| TRACED-RECEIPT-ONLY | `priv/ash_surface/xaas_ash_surface_client.mjs` | — | w214-staging-sequence.md, w224-drift-authority.md, x8-ash-surface-gen.md |
| TRACED-RECEIPT-ONLY | `priv/courts/substitution_policy_court.exs` | — | w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `priv/repo/migrations/20261006000000_repair_witness_certified_receipts.exs` | — | w136-migration-check.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `priv/repo/migrations/20261006212508_add_w247_convergence_snapshots.exs` | — | w146-chicago-suite.md, w214-staging-sequence.md, w258-migration-fix.md |
| TRACED-RECEIPT-ONLY | `priv/resource_snapshots/repo/actuation_intents/20261006212509.json` | — | w247-codegen.md, w223-verify-stages2.md, w258-migration-fix.md (dir-level: resource_snapshots + per-resource rows; filenames not cited) |
| TRACED-RECEIPT-ONLY | `priv/resource_snapshots/repo/actuation_receipts/20261006212512.json` | — | w247-codegen.md, w223-verify-stages2.md, w258-migration-fix.md (dir-level: resource_snapshots + per-resource rows; filenames not cited) |
| TRACED-RECEIPT-ONLY | `priv/resource_snapshots/repo/billing_revenue_recognitions/` | — | w247-codegen.md, w223-verify-stages2.md, w258-migration-fix.md (dir-level: resource_snapshots + per-resource rows; filenames not cited) |
| TRACED-RECEIPT-ONLY | `priv/resource_snapshots/repo/graphlaw_capabilities/` | — | w247-codegen.md, w223-verify-stages2.md, w258-migration-fix.md (dir-level: resource_snapshots + per-resource rows; filenames not cited) |
| TRACED-RECEIPT-ONLY | `priv/resource_snapshots/repo/graphlaw_engine_limits/` | — | w247-codegen.md, w223-verify-stages2.md, w258-migration-fix.md (dir-level: resource_snapshots + per-resource rows; filenames not cited) |
| TRACED-RECEIPT-ONLY | `priv/resource_snapshots/repo/ultracode_runs/20261006212513.json` | — | w247-codegen.md, w223-verify-stages2.md, w258-migration-fix.md (dir-level: resource_snapshots + per-resource rows; filenames not cited) |
| TRACED-RECEIPT-ONLY | `priv/resource_snapshots/repo/witness_certified_receipts/` | — | w247-codegen.md, w223-verify-stages2.md, w258-migration-fix.md (dir-level: resource_snapshots + per-resource rows; filenames not cited) |
| TRACED-RECEIPT-ONLY | `priv/resource_snapshots/repo/witness_verification_keys/` | — | w247-codegen.md, w223-verify-stages2.md, w258-migration-fix.md (dir-level: resource_snapshots + per-resource rows; filenames not cited) |
| TRACED | `priv/semantic/` | §1/§3 | vector4-gen-parity.md, w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED | `README.md` | §1/§3 | r10-wasm4pm.md, r6-ferroplan.md, r8-gymact.md, vector6-docs-abi.md, w114-commit-plan.md |
| TRACED-RECEIPT-ONLY | `scripts/semantic_replay_task.exs` | — | w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/fixtures/semantic_work/sj-001-descriptor.json` | — | w139-e4-adjudication.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/mix/tasks/xaas_ingest_capability_receipts_test.exs` | — | vector3-ignored-suites.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w353-fenced-rows-disposition.md, w69-gates-rerun.md |
| TRACED-RECEIPT-ONLY | `test/mix/tasks/xaas_refusal_render_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w244-format-regression.md |
| TRACED-RECEIPT-ONLY | `test/mix/tasks/xaas_self_digest_test.exs` | — | w228-mix-tasks-dir.md, w249-self-digest-isolation.md |
| TRACED-RECEIPT-ONLY | `test/mix/tasks/xaas_stop_court_test.exs` | — | vector1-fenced-gates.md, vector3-closure-receipt.md, vector3-ignored-suites.md, w107-schema-drift.md, w128-oracle-final.md |
| TRACED-RECEIPT-ONLY | `test/sjira/v26_9_23_goal_test.exs` | — | _INDEX.md, vector1-fenced-gates.md, vector3-ignored-suites.md, w107-schema-drift.md, w114-commit-plan.md |
| TRACED-RECEIPT-ONLY | `test/xaas_web/a2a/v1_protocol_test.exs` | — | w109-a2a-v1-court.md, w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas_web/a2a/v1_sse_test.exs` | — | w120-web-suite.md, w248-subprocess-token.md, w270-a2a-sse.md |
| TRACED-RECEIPT-ONLY | `test/xaas_web/a2a/zoe_event_simulation_agent_test.exs` | — | w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas_web/controllers/health_controller_test.exs` | — | w153-commit-plan-v2.md, w174-ontop-health-typing.md, w214-staging-sequence.md, w280-async-env-isolation.md, w301-env-isolation-final.md |
| TRACED | `test/xaas_web/endpoint_body_limit_test.exs` | §1/§3 | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w236-refusal-capstone.md, w51-integration-verify.md |
| TRACED-RECEIPT-ONLY | `test/xaas_web/execution_fabric_controller_test.exs` | — | w158-suite-with-token.md, w251-final-suite.md, w301-env-isolation-final.md |
| TRACED-RECEIPT-ONLY | `test/xaas_web/ggen_workbench_auth_floor_test.exs` | — | w214-staging-sequence.md, w260-ground-truth.md |
| TRACED-RECEIPT-ONLY | `test/xaas_web/live/marketplace_catalog_live_test.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas_web/live/marketplace_pplan_explorer_live_test.exs` | — | r5-pplan.md, w214-staging-sequence.md |
| TRACED | `test/xaas_web/live/witness_live_test.exs` | §1/§3 | w114-commit-plan.md, w120-web-suite.md, w136-migration-check.md, w153-commit-plan-v2.md, w191-final-hazards.md |
| TRACED | `test/xaas_web/plugs/require_internal_api_token_test.exs` | §1/§3 | w114-commit-plan.md, w13-plug-refusals.md, w153-commit-plan-v2.md, w158-suite-with-token.md, w214-staging-sequence.md |
| TRACED | `test/xaas/accounts/token_revocation_test.exs` | §1/§3 | _INDEX.md, w153-commit-plan-v2.md, w183-token-revocation-findings.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED | `test/xaas/actuation_refusal_negative_test.exs` | §1/§3 | w114-commit-plan.md, w13-plug-refusals.md, w131-operations-suite.md, w136-migration-check.md, w153-commit-plan-v2.md |
| TRACED-RECEIPT-ONLY | `test/xaas/actuation_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w321-unreachable-reverify.md, w69-gates-rerun.md |
| TRACED-RECEIPT-ONLY | `test/xaas/ash_surface_drift_guard_test.exs` | — | w114-commit-plan.md, w191-final-hazards.md, w214-staging-sequence.md, w224-drift-authority.md, w230-r2rml-skew.md |
| TRACED-RECEIPT-ONLY | `test/xaas/ash_surface_generator_test.exs` | — | w114-commit-plan.md, w191-final-hazards.md, w214-staging-sequence.md, w224-drift-authority.md, w281-class-d.md |
| TRACED-RECEIPT-ONLY | `test/xaas/autofde/status_parser_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/boundary_limits_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md, w69-gates-rerun.md |
| TRACED-RECEIPT-ONLY | `test/xaas/bridges/` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED | `test/xaas/castle_refusal_negative_batch2_test.exs` | §1/§3 | w114-commit-plan.md, w176-refusal-delta-recount.md, w214-staging-sequence.md, w236-refusal-capstone.md, w51-integration-verify.md |
| TRACED | `test/xaas/castle_refusal_negative_batch3_test.exs` | §1/§3 | w114-commit-plan.md, w176-refusal-delta-recount.md, w214-staging-sequence.md, w236-refusal-capstone.md, w51-integration-verify.md |
| TRACED | `test/xaas/castle_refusal_negative_batch4_test.exs` | §1/§3 | w114-commit-plan.md, w176-refusal-delta-recount.md, w214-staging-sequence.md, w236-refusal-capstone.md, w321-unreachable-reverify.md |
| TRACED-RECEIPT-ONLY | `test/xaas/castle_refusal_negative_batch5_test.exs` | — | w114-commit-plan.md, w176-refusal-delta-recount.md, w214-staging-sequence.md, w236-refusal-capstone.md |
| TRACED-RECEIPT-ONLY | `test/xaas/castle_refusal_negative_batch6_test.exs` | — | w153-commit-plan-v2.md, w176-refusal-delta-recount.md, w214-staging-sequence.md, w236-refusal-capstone.md, w244-format-regression.md |
| TRACED | `test/xaas/castle_refusal_negative_test.exs` | §1/§3 | w114-commit-plan.md, w153-commit-plan-v2.md, w176-refusal-delta-recount.md, w214-staging-sequence.md, w236-refusal-capstone.md |
| TRACED-RECEIPT-ONLY | `test/xaas/chicago/bridges/ex4pm_test.exs` | — | w214-staging-sequence.md |
| TRACED | `test/xaas/chicago/bridges/pplan_test.exs` | §1/§3 | _WIRING_MATRIX.md, r5-pplan.md, w146-chicago-suite.md, w214-staging-sequence.md, w41-pplan-facade.md |
| TRACED-RECEIPT-ONLY | `test/xaas/chicago/bridges/registry_test.exs` | — | r6-ferroplan.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/chicago/consumer/chicago_view_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/chicago/negative_courts/chicago_authority_courts_test.exs` | — | w214-staging-sequence.md, w280-async-env-isolation.md, w301-env-isolation-final.md |
| TRACED-RECEIPT-ONLY | `test/xaas/chicago/negative_courts/chicago_consequence_courts_test.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/chicago/negative_courts/chicago_evidence_courts_test.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/chicago/negative_courts/chicago_graph_courts_test.exs` | — | w146-chicago-suite.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/chicago/negative_courts/support/mutants.ex` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED | `test/xaas/chicago/seller/seller_live_test.exs` | §1/§3 | vector1-fenced-gates.md, vector3-ignored-suites.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/chicago/surface/command_center_adapter_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w353-fenced-rows-disposition.md, x8-ash-surface-gen.md |
| TRACED-RECEIPT-ONLY | `test/xaas/conference/conference_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w221-conference-a2a.md |
| TRACED-RECEIPT-ONLY | `test/xaas/eds/falsifier_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/fabric/castle_alive_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w354-commit-ready-freshness.md |
| TRACED | `test/xaas/generated/` | §1/§3 | vector4-gen-parity.md, w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/graphlaw/catalog_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/igniter/igniter_catalog_test.exs` | — | w114-commit-plan.md, w141-drift-regen.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w220-marketplace-igniter.md |
| TRACED-RECEIPT-ONLY | `test/xaas/mix/` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/ocel/ocpm_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/operations/capability_liveness_receipt_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w51-integration-verify.md |
| TRACED-RECEIPT-ONLY | `test/xaas/operations/gymact_surface_test.exs` | — | r8-gymact.md, w114-commit-plan.md, w153-commit-plan-v2.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/planning/stale_plan_gate_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/sa2a/court_stale_plan_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w198-sa2a-suite.md, w214-staging-sequence.md, w51-integration-verify.md |
| TRACED-RECEIPT-ONLY | `test/xaas/sa2a/execute_test.exs` | — | w198-sa2a-suite.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/sa2a/route_test.exs` | — | w153-commit-plan-v2.md, w198-sa2a-suite.md, w214-staging-sequence.md, w253-format-regression2.md |
| TRACED-RECEIPT-ONLY | `test/xaas/security/security_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/semantics/r2rml_refusal_test.exs` | — | w153-commit-plan-v2.md, w176-refusal-delta-recount.md, w214-staging-sequence.md, w236-refusal-capstone.md, w244-format-regression.md |
| TRACED | `test/xaas/semantics/vkg_refusal_negative_test.exs` | §1/§3 | w114-commit-plan.md, w153-commit-plan-v2.md, w18-vkg-refusals.md, w191-final-hazards.md, w214-staging-sequence.md |
| TRACED | `test/xaas/sjira/ard_court_test.exs` | §1/§3 | vector3-ignored-suites.md, w142-e5-e6.md, w153-commit-plan-v2.md, w155-registry-receipts.md, w210-vacuity-sweep.md |
| TRACED-RECEIPT-ONLY | `test/xaas/sjira/engineer_workflow_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/telemetry/ocel_ash_emitter_test.exs` | — | w153-commit-plan-v2.md, w214-staging-sequence.md, w253-format-regression2.md |
| TRACED-RECEIPT-ONLY | `test/xaas/topology_guard_test.exs` | — | w141-drift-regen.md, w153-commit-plan-v2.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/trimtab/context_budget_test.exs` | — | vector5-limits-lints.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/trimtab/falsifier_test.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/trimtab/recovery_test.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/ultracode/autonomic_profile_sense_test.exs` | — | w141-drift-regen.md, w192-ultracode-rerun.md, w253-format-regression2.md, w292-quiescence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/ultracode/machine_experience_test.exs` | — | w125-epa-sweep.md, w227-ultracode-dir.md, w245-property-token.md, w289-final-dod-suite.md, w290-cross-dir.md |
| TRACED | `test/xaas/ultracode/semantic_drive_anchor_test.exs` | §1/§3 | vector3-closure-receipt.md, vector3-ignored-suites.md, w108-sibling-build.md, w148-bridges-ultracode.md, w153-commit-plan-v2.md |
| TRACED-RECEIPT-ONLY | `test/xaas/ultracode/semantic_drive_plan_next_test.exs` | — | w125-epa-sweep.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/ultracode/semantic_drive_test.exs` | — | w125-epa-sweep.md, w227-ultracode-dir.md, w290-cross-dir.md |
| TRACED-RECEIPT-ONLY | `test/xaas/ultracode/semantic_jira_bridge_test.exs` | — | w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/ultracode/semantic_replay_test.exs` | — | w125-epa-sweep.md, w139-e4-adjudication.md, w153-commit-plan-v2.md, w158-suite-with-token.md, w192-ultracode-rerun.md |
| TRACED-RECEIPT-ONLY | `test/xaas/ultracode/sj_program_registry_test.exs` | — | vector1-fenced-gates.md, w141-drift-regen.md, w153-commit-plan-v2.md, w192-ultracode-rerun.md, w214-staging-sequence.md |
| TRACED-RECEIPT-ONLY | `test/xaas/witness/catalog_test.exs` | — | w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md, w245-property-token.md |
| TRACED | `VERSION` | §1/§3 | _INDEX.md, vector6-docs-abi.md, w114-commit-plan.md, w153-commit-plan-v2.md, w214-staging-sequence.md |

## Family rollup (same evidence, grouped)

| family | paths | provenance anchor |
|---|---|---|
| Playwright/e2e (specs, config, seed, global-setup, CI wf) | 22 | §4 P3-1/P3-2/P3-3; w191 PW commit group; per-spec receipts w111/w112/w113/w118/w135/w252/w259/w299/w302 |
| Witness surface (live, catalog, keys, migration, PW) | 7 | w191 witness group; w112/w135/w136/w245; §1 row 25-adjacent |
| Castle bridge (castle.ex, generated/*, shacl, docs page, ggen.lock, priv/semantic/) | 8 | §1 row 13, §3 commit-ready, P2-1; w36/w191/w334/w354 |
| ash_surface projections (priv/ash_surface/*, drift/generator tests, mix task) | 10 | §1 rows 12/15, P2-4; w73/w224/w336 |
| Refusal/boundary courts (castle_refusal batches 1-6, actuation, vkg, r2rml, boundary, token_revocation, plug/body-limit tests) | 15 | §2 (batches, w176 recount, w185/w208/w236 closure), P1-1/P1-2/P1-8 |
| A2A v1 surface (v1_transport_plug, a2a_parse_floor, next_read_ash_agent, v1_protocol/v1_sse tests, a2a-v1 spec) | 7 | w109/w113/w150/w270; §4 OS-1 (auth stacking decision still open) |
| Gymact surface (gymact_surface.ex + test) | 2 | §1 row 2, P0-1, w42 |
| Pplan bridge (pplan.ex + pplan_test) | 2 | §1 row 3, P0-3, w41 |
| Doc sweep (README, CHANGELOG, VERSION, diataxis x3, v26.9.21/22 sjira docs x17) | 22 | §3 P2-6 / vector6 §3 S1-S10; w328-docs-sweep-verify; v26.9.21/22 md files = w214 bulk staging (w244 format sweep) |
| Mix-task stragglers (10 lib/mix/tasks + 5 tests) | 15 | w106; w214 bulk; w107/w249/w321/w353 per-task |
| Config/mix seams (mix.exs, mix.lock, config x3) | 5 | §3 LOCK_STALE pins (x4 SEAMs); w174/w270/w41 pin receipts |
| Chicago/sa2a/ultracode/fabric/conference/graphlaw/eds courts | 60+ | w214 bulk staging + per-lane suites (w146/w198/w221/w227/w253/w280/w301) |
| DO-NOT-COMMIT scratch (GGEN-SH-*, .clap-noun-verb/, .ggen_igniter/receipts, ggen.lock*) | 5 | §3 "stays excluded"; w191 DO-NOT-COMMIT table |

## Receipt (law 7)

- Subject: /Users/sac/xaas @ feat/playwright-surface, working tree as of 2026-10-06, git status snapshot in-method.
- O: git status --porcelain (229 entries) + full receipt corpus (all *.md in plans/).
- μ: single-pass literal filename match, then dir/module-level fuzzy resolution for 9 misses; no file mutated except this receipt.
- Commands: git status --porcelain; git diff --cached --stat; python corpus grep (map at /tmp/w323-map.txt, ephemeral).
- Verification: counts recomputed from the map file, not asserted.
- Standing: review-time admission map only; commits coordinator-gated. UNTRACED=0.
- Falsifier: any path in a later git status lacking a row above, or a coordinator refusal of a path this map calls TRACED.
