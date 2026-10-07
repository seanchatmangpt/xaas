# W114 Integration Commit Plan — v26.10.6 Convergence

Lane W114 integration · 2026-10-06 · PLAN ONLY — no git mutations performed.
All inventories are verbatim `git status --porcelain` output collected 2026-10-06.

## Repo order (dependency order)

ggen → ggen-marketplace → ggen_igniter → ash_pplan → ash_a2a (park, no commits) → ash_surface → ferroplan → zcode-cli → gymact → wasm4pm → beam4pm (SKIP) → xaas

## Do-NOT-commit flags

| item | repo | reason |
|---|---|---|
| 5 staged rename entries `test/fixtures/ash_manufacture_pack/bin/__pycache__/*.pyc → priv/ggen/ash-manufacture-pack/bin/__pycache__/*.pyc` | ggen_igniter | compiled bytecode. PRE-STEP: unstage these 5 index entries, add `__pycache__/` to `.gitignore`, delete `priv/ggen/ash-manufacture-pack/bin/__pycache__/`. |
| `GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt` (mtime 11:55 today), `.clap-noun-verb/` (ocel.json, receipts.jsonl, 12:13 today), `.ggen_igniter/receipts/2026-10-06.jsonl` (12:42 today), `ggen.lock` (11:55 today) | xaas | same-day lane/runtime residue from today's ggen-sh runs. `ggen.lock` default-excluded; commit only if the coordinator confirms it is a release product, not scratch. |
| all 2495 dirty lines (2438 M + 53 ?? + 4 D, incl. `vendor/ggen-marketplace` submodule ptr) | /Users/sac/beam4pm | read-only-check qualification subject; not a convergence output. No path `/Users/sac/beam4pm-read-only-check` exists — actual checkout is `/Users/‌sac/beam4pm`. |
| `artifacts/` (mtime 12:12 today) | zcode-cli | build/test-run output from today's runs. |
| `docs/thesis/` (mtime 2026-10-05) | ash_a2a | ownerless (no W114 lane owns it); park, do not commit. |
| `_build-lane*` / `_build` dirs | all repos | none appear in any porcelain output (gitignored). Clean. |

Note: ferroplan's `crates/ferroplan-wasm/registry/ferroplan_wasm.wasm` (mtime 12:06 today) IS
committed — it is a convergent generated-output paired with the `.ggen-v2` receipts (dated
2026-10-01, stable), unlike the xaas/zcode-cli same-day scratch.

## 1. ggen (feat/v26.10.5-release-cut @ 000bffb8f — 8 files)

**C1 `chore(release): cut ggen v26.10.6 release metadata`**
```bash
git add .claude-plugin/marketplace.json .specify/repo-facts.ttl Cargo.lock Cargo.toml \
  crates/ggen-engine/Cargo.toml crates/pm4pytest-cli/Cargo.toml docs/CHANGELOG.md ggen.toml
```

## 2. ggen-marketplace (feat/aaif-gcp-roadmap-v26.10.5 @ 93895f808 — 2 files)

**C1 `chore(release): v26.10.6 marketplace catalog + changelog closure`**
```bash
git add CHANGELOG.md marketplace.active.toml
```

## 3. ggen_igniter (feat/adr-0010-gate-convention @ 7dbcdb3 — 61 lines: 30 M + 27 R + 4 untracked-dir lines)

**C0 pre-step** (see flag table): unstage 5 `__pycache__` pyc renames; gitignore + delete.

**C1 `feat(pack): promote ash-manufacture-pack from test fixture to canonical priv/ggen pack`**
```bash
git add priv/ggen/ash-manufacture-pack test/fixtures/ash_manufacture_pack
```
covers all 22 non-pyc rename entries (2 are RM — content edits).

**C2 `feat(gates): pack-catalog/gate-verify/verify-mutation support for the promoted pack`**
```bash
git add lib/ggen_igniter/pack_catalog.ex lib/ggen_igniter/gate_verify.ex \
  lib/ggen_igniter/verify_mutation.ex lib/ggen_igniter/render/tera_wasm.ex \
  lib/ggen_igniter/semantic_jira/sovereign_lease.ex lib/ggen_igniter/semantic_jira/transition_log.ex \
  lib/mix/tasks/ggen_igniter.verify.ex mix.exs
```
(mix.exs is version-closure ride-along; may split as its own `chore(release)`)

**C3 `test(pack): realign tests to canonical pack location + ADR-0010 gate convention`**
```bash
git add test/ggen_igniter_agent_guard_test.exs test/ggen_igniter_ash_gen_core_alignment_test.exs \
  test/ggen_igniter_ash_manufacture_pack_test.exs test/ggen_igniter_ash_task_coverage_test.exs \
  test/ggen_igniter_gate_verify_test.exs test/ggen_igniter_package_ash_free_test.exs \
  test/ggen_igniter_packs_task_test.exs test/ggen_igniter_verify_mutation_test.exs \
  test/mix/tasks/ggen_igniter_verify_task_test.exs test/support/postgres_case.ex
```

**C4 `docs(pack): ash-manufacture-pack promotion + ADR-0010 gate-convention docs`**
```bash
git add AGENTS.md CHANGELOG.md README.md docs/contributing/dev-setup.md \
  docs/contributing/testing.md docs/diataxis/how-to/verify-and-replay-a-pack.md \
  docs/integrations/ash/overview.md docs/status.md
```

## 4. ash_pplan (fix/ggen-verify-header @ 414a393 — 1 file)

**C1 `docs(demo): update demonstration walkthrough`** — `docs/demonstration.md`

## 5. ash_a2a (feat/tck-vuln-hardening @ 07180bd3) — NO COMMITS; park `docs/thesis/`.

## 6. ash_surface (main @ db5a889 — 55 lines: 49 M + 5 ??-dirs/files + doc/, docs/sjira/)

**C1 `feat(a2a-bridge): ash_surface A2A bridge surface`**
```bash
git add lib/ash_surface/a2a_bridge.ex test/ash_surface/a2a_bridge_test.exs
```

**C2 `feat(conformance): IR codec vectors + cross-language digest parity v3`**
```bash
git add conformance/ test/js/ test/support/digest_parity_fixtures.ex docs/DEP_GRAPH.md
```
(conformance/ = MANIFEST.json, known_divergences.mjs, replay.mjs, ir_codec.json,
surface_contract_digest.json; test/js/ = 9 modified .mjs tests + fixtures json)

**C3 `feat(projector): expo/aria/js/live_view projector closure + runtime regen`**
```bash
git add .gitignore ggen.toml mix.exs lib/ash_surface.ex lib/ash_surface/compiler.ex \
  lib/ash_surface/mx_episode.ex lib/ash_surface/projector/expo.ex \
  lib/ash_surface/projectors/aria.ex lib/ash_surface/projectors/js.ex \
  priv/static/ash_surface_runtime.mjs priv/verifier/verify_closure_episode.py \
  scripts/bump_version.sh scripts/conformance_regen.exs \
  docs/diataxis/reference/api.md docs/diataxis/tutorials/manifest-to-surface.md
```

**C4 `test(ash-surface): realign test suite to projector/codec closure`**
```bash
git add test/ash_surface/
```
(24 modified .exs files under test/ash_surface/)

**C5 `docs: lane sjira receipts + doc/ notes`**
```bash
git add doc/ docs/sjira/
```
(untracked dirs, mtimes 2026-10-03 / 2026-10-05 — stable, not same-day scratch)

## 6b. ferroplan (main @ c037876 — 5 lines)

**C1 `chore(generated): refresh ferroplan-wasm registry artifact + ggen-v2 receipts`**
```bash
git add .ggen-v2/receipt-log.jsonl .ggen-v2/receipt.json \
  crates/ferroplan-wasm/.ggen-v2/receipt-log.jsonl crates/ferroplan-wasm/.ggen-v2/receipt.json \
  crates/ferroplan-wasm/registry/ferroplan_wasm.wasm
```

## 7. zcode-cli (fix/v26926-preview-publish-typed-skip @ 7fc62da — 18 lines)

**C1 `feat(max-turns): subagent max-turns config surface + expert-strategy config tests`**
```bash
git add src/max-turns.ts src/launcher.ts scripts/sync-runtime.ts \
  test/max-turns.test.ts test/sync-runtime-anchor-drift.test.ts \
  test/expert-strategy-config.test.ts test/fixtures/max-turns/
```

**C2 `docs: configuration/host-integration/releasing/c4 doc closure`**
```bash
git add AGENTS.md HANDWRITTEN.md README.md docs/CONFIGURATION.md docs/CONFIGURATION.zh-CN.md \
  docs/HOST_INTEGRATION.md docs/RELEASING.md docs/c4-zcode-cli-xaas.md
```
`artifacts/` NOT committed (flagged).

## 8. gymact (v26926/gymact-land-aloop-execution-kernel @ d3eb5e8 — 7 files)

**C1 `feat(gyms): ggen/fastapi surface updates + v26.10.6 version closure`**
```bash
git add pyproject.toml src/gymact/__init__.py CHANGELOG.md README.md docs/reference.md \
  src/gymact/gyms/ggen.py src/gymact/surfaces/fastapi.py
```
(single atomic commit acceptable — 7 files, one convergence wave; split later if desired)

## 9. wasm4pm (fix/v26.9.30-ci-fmt-tsc @ 32deb59f6 — 4 files)

**C1 `chore(release): wasm4pm version bump + ml scaling test + receipt-truth doc`**
```bash
git add package.json apps/wasm4pm/README.md \
  docs/explanation/prd_ard_receipt_truth_verification.md \
  packages/ml/src/__tests__/algorithm-selection-with-scaling.test.ts
```

## 10. beam4pm — SKIPPED (read-only-check subject; 2495 dirty lines; do not commit this cycle).

## 11. xaas (feat/playwright-surface @ d1db2b03 — 165 lines: 122 M + 2 R + 41 ??)

**W114-X1 `chore(release): v26.10.6 version closure + dep pins`**
```bash
git add VERSION CHANGELOG.md README.md mix.exs mix.lock config/config.exs config/dev.exs
```
(diff-stat verified: VERSION 1-line, mix.lock 27-line pin change, config +14 lines)

**W114-X2 `feat(ash-surface): castle bridge contract/edges generation + surface runtime projection`**
```bash
git add lib/mix/tasks/xaas.ash_surface.ex lib/xaas/generated/ lib/xaas/bridges/ferroplan.ex \
  priv/ash_surface/ priv/semantic/ \
  docs/claude/diataxis/reference/generated-castle-bridge-errc.md \
  docs/claude/diataxis/reference/ash-configuration.md \
  docs/claude/diataxis/reference/http-api-surface.md
```
(lib/xaas/generated/ = castle_bridge_contract.ex + castle_bridge_edges.ex; priv/ash_surface/ = 5
modified projection files; priv/semantic/ untracked dir)

**W114-X3 `feat(witness): certified-receipt witness catalog + live surface`**
```bash
git add lib/xaas/witness/ lib/xaas_web/live/witness_live.ex \
  lib/xaas_web/a2a/next_read_ash_agent.ex \
  test/xaas/witness/catalog_test.exs test/xaas_web/live/witness_live_test.exs
```

**W114-X4 `feat(refusal-typing): typed refusal surface + negative court batteries`**
X4 lib files (path-inferred attribution — coordinator confirms via `git diff` before staging):
`lib/xaas/castle.ex, lib/xaas/fabric/failure.ex, lib/xaas/sa2a/court.ex,
lib/xaas/security/finding.ex, lib/xaas/chicago/layer.ex`
X4 test files (verbatim from porcelain):
`test/mix/tasks/xaas_refusal_render_test.exs,
test/xaas/actuation_refusal_negative_test.exs,
test/xaas/castle_refusal_negative_test.exs,
test/xaas/castle_refusal_negative_batch2_test.exs,
test/xaas/castle_refusal_negative_batch3_test.exs,
test/xaas/castle_refusal_negative_batch4_test.exs,
test/xaas/castle_refusal_negative_batch5_test.exs,
test/xaas/semantics/vkg_refusal_negative_test.exs,
test/xaas/boundary_limits_test.exs,
test/xaas_web/a2a/v1_protocol_test.exs,
test/xaas_web/endpoint_body_limit_test.exs,
test/xaas_web/plugs/require_internal_api_token_test.exs`

Coordinator stages the X4 lib files + these 12 test files as one `git add`. X4 lib attribution
is path-inferred (castle/fabric-failure/sa2a-court/security-finding/chicago-layer are the
refusal-producing surfaces); confirm with `git diff` before staging each lib file.

**W114-X5 `feat(playwright): e2e spec surface + CI workflow`**
```bash
git add e2e/ playwright.config.cjs .github/workflows/playwright-e2e.yml .github/workflows/ci_cd.yaml
```
(e2e/ covers the 2 staged renames .js→.cjs, 14 modified/untracked .cjs specs, global-setup.cjs)

**W114-X6 `test(xaas): bridge/gymact/witness-adjacent unit tests + bench updates`**
```bash
git add bench/ lib/xaas/operations/gymact_surface.ex \
  test/xaas/bridges/ test/xaas/operations/gymact_surface_test.exs \
  test/xaas/mix/ test/xaas/generated/
```

**W114-X7 `fix(lib): remaining lib + config surface updates from convergence`**
residual lib files not claimed by X2–X6 — verbatim list:
`lib/xaas/accounts/token.ex, lib/xaas/actuation.ex, lib/xaas/application.ex,
lib/xaas/autofde/status_parser.ex, lib/xaas/bridges/ex4pm.ex, lib/xaas/bridges/graphlaw.ex,
lib/xaas/bridges/pplan.ex, lib/xaas/bridges/registry.ex, lib/xaas/fabric.ex,
lib/xaas/fabric/planes/{actuation,evidence,law,process}.ex, lib/xaas/graphlaw/catalog.ex,
lib/xaas/operations/capability_liveness_receipt.ex, lib/xaas/ultracode/semantic_drive.ex,
lib/xaas/ultracode/semantic_drive/plan_next.ex,
lib/xaas_web/a2a/next_read_user_agent.ex, lib/xaas_web/a2a/zoe_event_simulation_agent.ex,
lib/xaas_web/controllers/health_controller.ex, lib/xaas_web/endpoint.ex,
lib/xaas_web/live/chicago/drill_down_live.ex, lib/xaas_web/live/marketplace_catalog_live.ex,
lib/xaas_web/live/marketplace_pplan_explorer_live.ex,
lib/xaas_web/live/system/{command_center_adapter,command_center_live}.ex,
lib/xaas_web/plugs/stripe_raw_body_reader.ex, lib/xaas_web/router.ex,
lib/mix/tasks/{xaas.capability_coverage,xaas.fabric.redeploy,xaas.ingest_capability_receipts,
xaas.release_audit,xaas.release_snapshot.verify,xaas.run_validate,xaas.safe_generate_migrations,
xaas.self_digest,xaas.sjira.engineer_work,xaas.stop_court}.ex`

**W114-X8 `test(xaas): realign remaining test suite to v26.10.6 convergence`**
residual test files not claimed by X3/X4/X6 — verbatim list:
`test/sjira/v26_9_23_goal_test.exs, test/xaas/actuation_test.exs,
test/xaas/autofde/status_parser_test.exs,
test/xaas/chicago/bridges/{ex4pm,pplan,registry}_test.exs,
test/xaas/chicago/consumer/chicago_view_test.exs,
test/xaas/chicago/negative_courts/chicago_{authority,consequence,evidence,graph}_courts_test.exs,
test/xaas/chicago/negative_courts/support/mutants.ex,
test/xaas/chicago/seller/seller_live_test.exs,
test/xaas/chicago/surface/command_center_adapter_test.exs,
test/xaas/conference/conference_test.exs, test/xaas/eds/falsifier_test.exs,
test/xaas/fabric/castle_alive_test.exs, test/xaas/graphlaw/catalog_test.exs,
test/xaas/igniter/igniter_catalog_test.exs, test/xaas/ocel/ocpm_test.exs,
test/xaas/operations/capability_liveness_receipt_test.exs,
test/xaas/planning/stale_plan_gate_test.exs, test/xaas/sa2a/court_stale_plan_test.exs,
test/xaas/security/security_test.exs, test/xaas/sjira/engineer_workflow_test.exs,
test/xaas/trimtab/{context_budget,falsifier,recovery}_test.exs,
test/xaas/ultracode/{semantic_drive_plan_next,semantic_jira_bridge}_test.exs,
test/xaas/ash_surface_drift_guard_test.exs, test/xaas/ash_surface_generator_test.exs`

(vkg refusal test belongs to X4, not X8.)

**W114-X9 `docs(sjira): v26.10.6 lane receipts + plans (incl. this plan)`**
```bash
git add docs/sjira/v26.10.6/
```

## Sequenced execution table

| # | repo | commit | message | files |
|---|---|---|---|---|
| 1 | ggen | C1 | chore(release): cut ggen v26.10.6 release metadata | 8 |
| 2 | ggen-marketplace | C1 | chore(release): v26.10.6 marketplace catalog + changelog closure | 2 |
| 3 | ggen_igniter | C0 pre-step | unstage 5 pyc renames + gitignore `__pycache__/` | 0 (index fix) |
| 4 | ggen_igniter | C1 | feat(pack): promote ash-manufacture-pack to priv/ggen | 22 |
| 5 | ggen_igniter | C2 | feat(gates): pack-catalog/gate-verify/verify-mutation | 8 |
| 6 | ggen_igniter | C3 | test(pack): realign tests to canonical pack | 10 |
| 7 | ggen_igniter | C4 | docs(pack): promotion + ADR-0010 docs | 8 |
| 8 | ash_pplan | C1 | docs(demo): update demonstration walkthrough | 1 |
| 9 | ash_surface | C1 | feat(a2a-bridge): A2A bridge surface | 2 |
| 10 | ash_surface | C2 | feat(conformance): IR codec vectors + digest parity v3 | 15 |
| 11 | ash_surface | C3 | feat(projector): projector closure + runtime regen | 15 |
| 12 | ash_surface | C4 | test(ash-surface): realign test suite | 24 |
| 13 | ash_surface | C5 | docs: lane sjira receipts + doc/ notes | 2 dirs |
| 14 | ferroplan | C1 | chore(generated): wasm registry artifact + receipts | 5 |
| 15 | zcode-cli | C1 | feat(max-turns): max-turns config surface + tests | 10 |
| 16 | zcode-cli | C2 | docs: configuration/host/releasing/c4 closure | 8 |
| 17 | gymact | C1 | feat(gyms): surface updates + version closure | 7 |
| 18 | wasm4pm | C1 | chore(release): version bump + ml scaling test + doc | 4 |
| 19 | xaas | X1 | chore(release): version closure + dep pins | 7 |
| 20 | xaas | X2 | feat(ash-surface): castle bridge + runtime projection | ~12 |
| 21 | xaas | X3 | feat(witness): witness catalog + live surface | 6 |
| 22 | xaas | X4 | feat(refusal-typing): refusal surface + negative courts | 17 |
| 23 | xaas | X5 | feat(playwright): e2e specs + CI workflows | e2e/ + 2 |
| 24 | xaas | X6 | test(xaas): bridge/gymact tests + bench | ~10 |
| 25 | xaas | X7 | fix(lib): remaining lib surface updates | ~35 |
| 26 | xaas | X8 | test(xaas): realign remaining tests | ~30 |
| 27 | xaas | X9 | docs(sjira): v26.10.6 lane receipts (incl. this plan) | 1 dir |
| — | ash_a2a / beam4pm | — | parked / skipped per flag table | — |

## Verification (coordinator runs after commits)

```bash
for r in xaas ash_surface ggen ggen-marketplace ggen_igniter ash_pplan zcode-cli gymact ferroplan wasm4pm; do
  echo "== $r"; git -C /Users/sac/$r status --porcelain
done
# expected residue: only flagged items (xaas ggen-sh scratch, zcode-cli artifacts/, ash_a2a docs/thesis/, beam4pm untouched)
```

## Receipt fields

- subject: W114 integration plan, branch/HEADs cited per repo above
- transport failures: 1 — `/Users/sac/beam4pm-read-only-check` does not exist; actual checkout `/Users/sac/beam4pm`
- standing: PLAN ONLY — no commits executed; every `git add` line is a coordinator command, not an executed action
- falsifier: coordinator's post-commit `git status --porcelain` sweep shows residue beyond the flagged set, or a commit's file count diverges from the plan's count column
