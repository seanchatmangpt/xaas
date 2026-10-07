# W214 Final Staging Sequence — xaas v26.10.6 Convergence

Lane: W214 integration. Subject: branch `feat/playwright-surface`, fresh `git status --porcelain`
at receipt time: **212 lines** (153 `M`, 57 `??`, 2 `R`; snapshot drifted +1 `M` during
receipt production — groups are path-keyed, so the delta is absorbed by its group). Every line is resolved below into
exactly one group or the exclusion list — no orphans. READ-ONLY plan; no git mutations
performed by W214.

## DO-NOT-COMMIT exclusions (W191, carried forward)

NEVER `git add` these; they are tool/logs/receipt-cache, not repo content:

- `ggen.lock`
- `GGEN-SH-AFTER-MIX-COMPILE.log`
- `GGEN-SH-AFTER-PROOF.txt`
- `.clap-noun-verb/`
- `.ggen_igniter/receipts/2026-10-06.jsonl`

(5 lines excluded; 206 lines staged.)

## Gate re-runs required at stage time

| Group | Gate | Command | Condition |
|---|---|---|---|
| G6 generated | ash-surface drift guard | `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/ash_surface_drift_guard_test.exs test/xaas/ash_surface_generator_test.exs` | always (regenerated output must match generator at current SHA) |
| G5/G9 refusal tests | refusal negative courts | `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/actuation_refusal_negative_test.exs test/xaas/castle_refusal_negative_test.exs test/xaas/castle_refusal_negative_batch{2,3,4,5,6}_test.exs test/xaas/semantics/r2rml_refusal_test.exs test/xaas/semantics/vkg_refusal_negative_test.exs` | **if W185 landed** — refusal tests trail their lib commit; run BEFORE the G9 commit, not after |
| G5/G9 general | mock gate | `PATH=$HOME/.asdf/shims:$PATH mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'` → expect `[]` | always, before any lib/test commit |
| G10 e2e | Playwright surface | `npx playwright test --project=chromium` (seed first: `mix run e2e/seed-witness.exs`) | if the running server has INTERNAL_API_TOKEN set; disclose if skipped |

All mix commands under the pinned asdf toolchain; `MIX_ENV=test` only (no dev compile — live phx).

## Ordered staging sequence

### G1 — deps/pins (FIRST)

```bash
git add mix.exs mix.lock
```

Message: `build(deps): pin v26.10.6 dependency set (mix.exs/mix.lock)` *(2 lines)*

### G2 — release metadata

```bash
git add VERSION CHANGELOG.md README.md
```

Message: `chore(release): v26.10.6 version bump + changelog + README` *(3 lines)*

### G3 — config

```bash
git add config/config.exs config/dev.exs config/test.exs
```

Message: `chore(config): v26.10.6 config alignment (compile/prod gates, test env)` *(3 lines)*

### G4 — CI

```bash
git add .github/workflows/ci_cd.yaml .github/workflows/playwright-e2e.yml
```

Message: `ci: add playwright-e2e workflow, update ci_cd for v26.10.6` *(2 lines)*

### G5 — lib fixes (hand-written source; depends on G1)

```bash
git add lib/mix/tasks/xaas.ash_surface.ex \
  lib/mix/tasks/xaas.capability_coverage.ex \
  lib/mix/tasks/xaas.fabric.redeploy.ex \
  lib/mix/tasks/xaas.ingest_capability_receipts.ex \
  lib/mix/tasks/xaas.release_audit.ex \
  lib/mix/tasks/xaas.release_snapshot.verify.ex \
  lib/mix/tasks/xaas.run_validate.ex \
  lib/mix/tasks/xaas.safe_generate_migrations.ex \
  lib/mix/tasks/xaas.self_digest.ex \
  lib/mix/tasks/xaas.sjira.engineer_work.ex \
  lib/mix/tasks/xaas.stop_court.ex \
  lib/xaas/a2a/agent.ex lib/xaas/a2a/task.ex \
  lib/xaas/accounts/token.ex lib/xaas/actuation.ex lib/xaas/application.ex \
  lib/xaas/autofde/status_parser.ex \
  lib/xaas/bridges/ex4pm.ex lib/xaas/bridges/graphlaw.ex lib/xaas/bridges/pplan.ex \
  lib/xaas/bridges/registry.ex lib/xaas/bridges/ferroplan.ex \
  lib/xaas/castle.ex lib/xaas/chicago/layer.ex \
  lib/xaas/conference/attendee.ex lib/xaas/conference/event.ex \
  lib/xaas/conference/registration.ex lib/xaas/conference/session.ex \
  lib/xaas/conference/speaker.ex lib/xaas/conference/sponsor.ex \
  lib/xaas/conference/track.ex \
  lib/xaas/eds/falsifier.ex \
  lib/xaas/fabric.ex lib/xaas/fabric/failure.ex \
  lib/xaas/fabric/planes/actuation.ex lib/xaas/fabric/planes/evidence.ex \
  lib/xaas/fabric/planes/law.ex lib/xaas/fabric/planes/process.ex \
  lib/xaas/graphlaw/catalog.ex \
  lib/xaas/igniter/pack_manifest.ex lib/xaas/igniter/refusal_code.ex \
  lib/xaas/marketplace/pack.ex \
  lib/xaas/operations/capability_liveness_receipt.ex lib/xaas/operations/gymact_surface.ex \
  lib/xaas/sa2a/court.ex lib/xaas/security/finding.ex \
  lib/xaas/ultracode/semantic_drive.ex lib/xaas/ultracode/semantic_drive/plan_next.ex \
  lib/xaas/witness/catalog.ex lib/xaas/witness/certified_receipt.ex \
  lib/xaas/witness/verification_key.ex \
  lib/xaas_web/a2a/next_read_user_agent.ex lib/xaas_web/a2a/next_read_ash_agent.ex \
  lib/xaas_web/a2a/zoe_event_simulation_agent.ex \
  lib/xaas_web/controllers/execution_fabric_controller.ex \
  lib/xaas_web/controllers/health_controller.ex \
  lib/xaas_web/endpoint.ex \
  lib/xaas_web/live/chicago/drill_down_live.ex \
  lib/xaas_web/live/marketplace_catalog_live.ex \
  lib/xaas_web/live/marketplace_pplan_explorer_live.ex \
  lib/xaas_web/live/witness_live.ex \
  lib/xaas_web/live/system/command_center_adapter.ex \
  lib/xaas_web/live/system/command_center_live.ex \
  lib/xaas_web/plugs/stripe_raw_body_reader.ex \
  lib/xaas_web/plugs/a2a_parse_floor.ex \
  lib/xaas_web/router.ex
```

Message: `fix(lib): v26.10.6 convergence — witness domain, ferroplan bridge, a2a parse floor, gymact surface, refusal codes` *(66 lines: 61 M + 5 new)*

### G6 — generated outputs (depends on G5 generators)

```bash
git add lib/xaas/generated/castle_bridge_contract.ex \
  lib/xaas/generated/castle_bridge_edges.ex \
  priv/semantic/generated/castle_bridge_shacl.ttl \
  priv/ash_surface/aria.json priv/ash_surface/ash_surface_runtime.mjs \
  priv/ash_surface/live_view.json priv/ash_surface/surface_contract.json \
  priv/ash_surface/xaas_ash_surface_client.mjs
```

Message: `chore(generated): regenerate castle-bridge contract/edges/SHACL + ash_surface projection` *(8 lines)*

Gate: drift guard (table above) BEFORE this commit.

### G7 — migration

```bash
git add priv/repo/migrations/20261006000000_repair_witness_certified_receipts.exs
```

Message: `fix(repo): repair witness certified_receipts migration` *(1 line)*

Note (W263): the W258 dedup fix changed how W247's generator emits snapshots — the
migration below is the regenerated (deduplicated) surface, not a duplicate of an
earlier migration; the commit message should say so.

### G7b — W247 convergence snapshots migration (sibling of G7, added by W263)

W263 inventory (real output): `ls priv/repo/migrations/ | tail -3` →
`20261005235901_add_graphlaw_engine_registry.exs`,
`20261006000000_repair_witness_certified_receipts.exs`,
`20261006212508_add_w247_convergence_snapshots.exs`.
`git status --porcelain priv/repo/migrations/ priv/feature/` → 2 `??` lines, both
migrations; no new files under `priv/feature/`. This file was absent from the original
W214 staging groups.

```bash
git add priv/repo/migrations/20261006212508_add_w247_convergence_snapshots.exs
```

Message: `chore(repo): add W247 convergence snapshots migration (post-W258 dedup fix)`

### G8 — scripts / courts / bench

```bash
git add scripts/semantic_replay_task.exs priv/courts/substitution_policy_court.exs \
  bench/prometheus_proxy_error_path_bench.exs bench/sjira_atlassian_projection.exs \
  bench/sjira_atlassian_transport.exs bench/sjira_engineer_workflow.exs
```

Message: `chore(scripts): semantic replay task, substitution policy court, bench alignment` *(6 lines)*

### G9 — tests (depends on G5/G6/G7)

```bash
git add test/fixtures/semantic_work/sj-001-descriptor.json \
  test/mix/tasks/xaas_ingest_capability_receipts_test.exs \
  test/mix/tasks/xaas_refusal_render_test.exs \
  test/mix/tasks/xaas_stop_court_test.exs \
  test/sjira/v26_9_23_goal_test.exs \
  test/xaas/actuation_test.exs test/xaas/actuation_refusal_negative_test.exs \
  test/xaas/accounts/token_revocation_test.exs \
  test/xaas/ash_surface_drift_guard_test.exs test/xaas/ash_surface_generator_test.exs \
  test/xaas/autofde/status_parser_test.exs \
  test/xaas/boundary_limits_test.exs \
  test/xaas/bridges/ \
  test/xaas/castle_refusal_negative_test.exs \
  test/xaas/castle_refusal_negative_batch2_test.exs \
  test/xaas/castle_refusal_negative_batch3_test.exs \
  test/xaas/castle_refusal_negative_batch4_test.exs \
  test/xaas/castle_refusal_negative_batch5_test.exs \
  test/xaas/castle_refusal_negative_batch6_test.exs \
  test/xaas/chicago/bridges/ex4pm_test.exs test/xaas/chicago/bridges/pplan_test.exs \
  test/xaas/chicago/bridges/registry_test.exs \
  test/xaas/chicago/consumer/chicago_view_test.exs \
  test/xaas/chicago/negative_courts/chicago_authority_courts_test.exs \
  test/xaas/chicago/negative_courts/chicago_consequence_courts_test.exs \
  test/xaas/chicago/negative_courts/chicago_evidence_courts_test.exs \
  test/xaas/chicago/negative_courts/chicago_graph_courts_test.exs \
  test/xaas/chicago/negative_courts/support/mutants.ex \
  test/xaas/chicago/seller/seller_live_test.exs \
  test/xaas/chicago/surface/command_center_adapter_test.exs \
  test/xaas/conference/conference_test.exs \
  test/xaas/eds/falsifier_test.exs \
  test/xaas/fabric/castle_alive_test.exs \
  test/xaas/generated/ \
  test/xaas/graphlaw/catalog_test.exs \
  test/xaas/igniter/igniter_catalog_test.exs \
  test/xaas/mix/ \
  test/xaas/ocel/ocpm_test.exs \
  test/xaas/operations/capability_liveness_receipt_test.exs \
  test/xaas/operations/gymact_surface_test.exs \
  test/xaas/planning/stale_plan_gate_test.exs \
  test/xaas/sa2a/court_stale_plan_test.exs test/xaas/sa2a/execute_test.exs \
  test/xaas/sa2a/route_test.exs \
  test/xaas/security/security_test.exs \
  test/xaas/semantics/r2rml_refusal_test.exs \
  test/xaas/semantics/vkg_refusal_negative_test.exs \
  test/xaas/sjira/ard_court_test.exs test/xaas/sjira/engineer_workflow_test.exs \
  test/xaas/telemetry/ocel_ash_emitter_test.exs \
  test/xaas/topology_guard_test.exs \
  test/xaas/trimtab/context_budget_test.exs test/xaas/trimtab/falsifier_test.exs \
  test/xaas/trimtab/recovery_test.exs \
  test/xaas/ultracode/semantic_drive_anchor_test.exs \
  test/xaas/ultracode/semantic_drive_plan_next_test.exs \
  test/xaas/ultracode/semantic_jira_bridge_test.exs \
  test/xaas/ultracode/semantic_replay_test.exs \
  test/xaas/ultracode/sj_program_registry_test.exs \
  test/xaas/witness/catalog_test.exs \
  test/xaas_web/a2a/v1_protocol_test.exs \
  test/xaas_web/a2a/zoe_event_simulation_agent_test.exs \
  test/xaas_web/controllers/health_controller_test.exs \
  test/xaas_web/endpoint_body_limit_test.exs \
  test/xaas_web/ggen_workbench_auth_floor_test.exs \
  test/xaas_web/live/marketplace_catalog_live_test.exs \
  test/xaas_web/live/marketplace_pplan_explorer_live_test.exs \
  test/xaas_web/live/witness_live_test.exs \
  test/xaas_web/plugs/require_internal_api_token_test.exs
```

Message: `test: v26.10.6 convergence — refusal courts, witness/v1-protocol/ferroplan coverage, trimtab realignment` *(70 lines: 47 M + 23 new, incl. 3 new dirs)*

Gate: mock gate + refusal suites (table above) BEFORE this commit.

### G10 — e2e + playwright (depends on G5)

```bash
git add playwright.config.cjs \
  e2e/ash-admin-destroy.spec.cjs e2e/ash-admin-state-change.spec.cjs \
  e2e/next-read-ml.spec.cjs e2e/wd-fa-cs2.spec.cjs \
  e2e/a2a-v1.spec.cjs e2e/ash-admin-matrix.spec.cjs e2e/ash-surface-client.spec.cjs \
  e2e/autofde-lab.spec.cjs e2e/chicago-pplan-deep.spec.cjs e2e/dev-routes.spec.cjs \
  e2e/execution-fabric.spec.cjs e2e/ggen-workbench.spec.cjs e2e/global-setup.cjs \
  e2e/internal-api.spec.cjs e2e/mcp-a2a.spec.cjs e2e/seed-witness.exs \
  e2e/sparql-proxy.spec.cjs e2e/stripe-webhook.spec.cjs e2e/system-deep.spec.cjs \
  e2e/witness.spec.cjs e2e/zcode-cli-fabric.spec.cjs
```

Message: `test(e2e): playwright surface — v1 protocol, witness, fabric, dev-routes specs; js→cjs rename` *(22 lines: 2 R + 2 M e2e + 17 new e2e + playwright.config.cjs)*

### G11 — docs/plans (LAST; includes this receipt)

```bash
git add docs/sjira/v26.10.6/ \
  docs/claude/diataxis/explanation/architecture-overview.md \
  docs/claude/diataxis/reference/actuation-and-semantics.md \
  docs/claude/diataxis/reference/ash-configuration.md \
  docs/claude/diataxis/reference/http-api-surface.md \
  docs/claude/diataxis/reference/generated-castle-bridge-errc.md \
  docs/sjira/v26.9.21/001-xaas-semantic-jira-e2e.md \
  docs/sjira/v26.9.21/002-zcode-ocel-pack-consumer.md \
  docs/sjira/v26.9.21/003-handwritten-paydown-zcode-plugin.md \
  docs/sjira/v26.9.21/004-resource-adoption-registry-exemptions.md \
  docs/sjira/v26.9.21/005-zoe-simulation-reconcile.md \
  docs/sjira/v26.9.21/006-ecosystem-standing-foldin.md \
  docs/sjira/v26.9.21/007-ash-atlassian-target.md \
  docs/sjira/v26.9.21/008-gymact-open-backlog.md \
  docs/sjira/v26.9.21/009-ash-ai-dependency-retest.md \
  docs/sjira/v26.9.21/010-atlassian-public-vocab-pin.md \
  docs/sjira/v26.9.21/011-public-ash-projection-extend.md \
  docs/sjira/v26.9.21/012-ash-atlassian-profile-admit.md \
  docs/sjira/v26.9.21/admit.exs docs/sjira/v26.9.21/generate.py \
  docs/sjira/v26.9.21/receipts/sa2a_post_SJ-003.exs \
  docs/sjira/v26.9.21/sa2a_loop.exs \
  docs/sjira/v26.9.22/sa2a_loop.exs docs/sjira/v26.9.22/shacl.exs
```

Message: `docs: v26.10.6 diataxis reference updates, historical sjira receipts, W214 staging plan` *(24 lines: 22 M + 2 new `??` lines — the `docs/sjira/v26.10.6/` line covers this file and `_CLOSURE_PLAN.md`)*

## Accounting

- `git status --porcelain` at receipt time: **212 lines** (153 `M`, 57 `??`, 2 `R`)
- Excluded (DO-NOT-COMMIT): **5** (`ggen.lock`, 2 GGEN-SH logs, `.clap-noun-verb/`, `.ggen_igniter/receipts/2026-10-06.jsonl`)
- Staged across G1–G11: **207 porcelain lines** (2+3+3+2+66+8+1+6+70+22+24 = 207; 211 file paths — the two `e2e/*.js → *.cjs` renames contribute 2 lines each within G10, and `docs/sjira/v26.10.6/` is one `??` line covering multiple files)

## Ambiguous assignments — coordinator review

1. **`priv/courts/substitution_policy_court.exs` (G8)** — executable court script under `priv/`; could argue G5 (lib-adjacent) or G9 (test support). Placed in G8 as non-test executable; low risk either way.
2. **`scripts/semantic_replay_task.exs` (G8)** — a `.exs` task runner; if it is required by a mix alias at compile/test time it belongs with G5. Coordinator: confirm `mix.exs aliases` does not reference it before deferring past G5.
3. **`docs/sjira/v26.9.21/sa2a_loop.exs`, `admit.exs`, `v26.9.22/{sa2a_loop,shacl}.exs` (G11)** — executable historical receipts under docs trees. Kept with their docs (historical provenance), but if any are re-run by gates at v26.10.6 they should move ahead of G9.
4. **`e2e/seed-witness.exs` (G10)** — seeding script vs. test-support; kept with e2e since only Playwright consumes it. Requires INTERNAL_API_TOKEN + running server at stage time.
5. **`test/xaas/generated/` + `test/xaas/bridges/` + `test/xaas/mix/` staged as directories (G9)** — contents verified at receipt time: `castle_bridge_contract_test.exs`, `ferroplan_test.exs`, `tasks/capability_coverage_test.exs` respectively. Only current contents; re-check before `git add` if lanes are still writing.
6. **`docs/sjira/v26.10.6/` staged as directory (G11)** — includes `_CLOSURE_PLAN.md`, `plans/` (this file). Lane output still landing here must complete before the G11 commit (G11 is last by design).

## W242 consistency verdict

Cross-check of w153-commit-plan-v2.md (+W201/W204 deltas), w191-final-hazards.md,
w214-staging-sequence.md (this file), w225-repo-staging.md (+W241). Resolution rule:
**W191 hazards > W225/W214 sequences > W153-v2 base**.

### Per-doc status

- **w191-final-hazards.md — CURRENT.** Authoritative hazard classification. Where W153-v2
  or this file disagree with it, W191 governs.
- **w225-repo-staging.md — CURRENT** (for the 10 non-xaas repos). Already applies the
  resolution rule (ferroplan resolved to W191: no commit; ash_pplan resolved by fresh
  porcelain; `doc/` flagged). Its ambiguity flags 1–3 stand for the coordinator.
- **w214-staging-sequence.md — CURRENT with two corrections** (see conflicts C1, C3 below):
  G6 must drop `priv/semantic/generated/castle_bridge_shacl.ttl` (or record coordinator
  admission of the castle-bridge pack-pin group); the exclusion list must add the
  `_build-lane*/`/`_build-w136`/`_build-w150` cleanup-law deletions as a pre-G1 step.
- **w153-commit-plan-v2.md — SUPERSEDED IN PART.** Still current as inventory detail and
  W201/W204 deltas, but superseded by W191 on: ferroplan 6b (wasm blob + `.ggen-v2/`
  receipts now DO-NOT-COMMIT, no ferroplan commit this cycle), ash_surface `doc/`
  (W191: build output; W225 default: exclude if unexamined), and `priv/semantic/generated/
  castle_bridge_shacl.ttl` (W191: DO-NOT-COMMIT absent coordinator admission; X2's
  `priv/semantic/` glob and W214 G6 both stage it — must not).

### Contradictions found

- **C1 — `priv/semantic/generated/castle_bridge_shacl.ttl`** (real conflict, three docs,
  three dispositions): W191 DO-NOT-COMMIT (admission condition: coordinator admits the
  castle-bridge pack pin as a group, same as `ggen.lock`); W153-v2 X2 stages `priv/semantic/`;
  W214 G6 stages the file explicitly with no condition. Resolution: W191 wins — G6 stages
  it only if the coordinator makes the same explicit admission as for `ggen.lock`; otherwise
  it belongs on the DO-NOT-COMMIT list, from which W214 omits it (hazard-list omission).
- **C2 — ash_surface `fixture/`** (real conflict): W191 classifies `fixture/burn_in/` as
  **COMMIT** ("deliberate deliverable per mtime-rule exception"); W225 row 61 and W153-v2
  park the whole `fixture/` with the courts. Note W191's COMMIT rationale concerns
  `fixture/burn_in/`, while the red-suite blocker concerns `fixture/composition_specimens/`
  (absent from disk, referenced by the parked courts). Resolution under the rule is
  technically W191-commit for `burn_in/`; W225's blanket park is defensible only if the
  coordinator keeps the courts parked and does not want an orphan fixture commit.
  **Unresolved for coordinator:** commit `fixture/burn_in/` alone (W191) or keep parked
  with the courts (W225). W191's own text is self-inconsistent here: it lists `fixture/`
  nowhere in DO-NOT-COMMIT/PARKED for ash_surface yet W153-v2's flag table and W225 park it.
- **C3 — lane build roots** (hazard-list omission in W214): W191 requires the coordinator
  to delete `_build-laneW125/`, `_build-laneW141/`, `_build-w136/`, `_build-w150/` at
  integration BEFORE the final commit (2026-10-01 cleanup law). W214's exclusions and
  sequence never mention them. W225 also omits them. Add as a pre-G1 cleanup step.
- **C4 — group-order conflict, xaas opening commits**: W153-v2 X1 is one commit
  (VERSION/CHANGELOG/README/mix.exs/mix.lock/config.exs/dev.exs); W214 splits into
  G1 (deps FIRST) → G2 (release) → G3 (config incl. `config/test.exs`, which W153-v2 X1
  omits entirely — inventory omission). Order itself is compatible (both put deps/config
  before lib); the split is a refinement, not a blocker. Coordinator follows W214 G1–G3.
- **C5 — group-shape conflict, xaas e2e/CI**: W153-v2 X5 is one commit (e2e/ +
  playwright.config.cjs + both workflows); W214 splits CI into G4 (early) and e2e into
  G10 (late, after G5 lib). W214's ordering is sounder (workflow gates run after lib
  lands); superseded-in-part, not a contradiction of dispositions.
- **C6 — batch6/r2rml courts**: W153-v2 W204 delta stages them in a trailing commit only
  if W185 has not landed; W214 G9 includes them unconditionally. No disposition conflict
  (both commit them), only placement — W214 governs; the G5/G9 gate table already handles
  the W185 condition.
- **C7 — count drift (no path conflict)**: ash_surface courts 24 (W153-v2) vs 30/31 (W191/W225);
  wasm4pm 28 (W191) vs 26 (W225, fresh); ash_pplan 2 files (W191 COMMIT list) vs 1 (W153-v2
  "unchanged" and W225 fresh porcelain). W225's fresh-observation resolutions stand.
- **C8 — ash_a2a**: W153-v2 body says "NO COMMITS"; its own W201 delta supersedes that
  (3 commits), and W225 folds the delta. Consistent chain; no conflict.

### Coordinator action list

1. Resolve C1 before G6: either admit the castle-bridge pack-pin group (`ggen.lock` +
   `castle_bridge_shacl.ttl` together) or add the SHACL to the exclusion list.
2. Resolve C2: `fixture/burn_in/` commit-alone vs parked-with-courts.
3. Add the C3 build-root deletions as a pre-G1 integration step (cleanup law).
4. Carry W225 ambiguity flags 1–3 (ash_surface `doc/` inspection-or-exclude; ash_pplan
   provider file; marketplace C2 pairing debt).
5. Re-pull fresh porcelain immediately before execution — three docs show count drift
   within one day (C7).

## W263 migration group

Integration lane W263, v26.10.6 convergence. W247's generated migration
(post-W258 dedup fix) is a new commit-surface file that was missing from W214's
staging groups. Real inventory at update time:

- `ls priv/repo/migrations/ | tail -3` →
  `20261005235901_add_graphlaw_engine_registry.exs`,
  `20261006000000_repair_witness_certified_receipts.exs` (already G7),
  `20261006212508_add_w247_convergence_snapshots.exs` (**new, untracked**).
- `git status --porcelain priv/repo/migrations/ priv/feature/` → exactly 2 `??`
  lines (the two migrations above); no new snapshot files under `priv/feature/`.

Resolution: new group **G7b** (above), staged immediately after G7, same
explicit-path `git add` style. Its commit message notes the W258 dedup fix so the
migration is not misread as a duplicate. Accounting: staged-line total moves
207 → 208; no other groups touched. Read-only elsewhere; no git operations
performed by W263.
