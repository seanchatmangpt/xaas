# W153 Integration Commit Plan v2 — v26.10.6 Convergence (refresh of W114)

Lane W153 integration · 2026-10-06 · PLAN ONLY — no git mutations performed.
All inventories are verbatim `git status --porcelain` output collected 2026-10-06 (afternoon,
post-W114). W114's structure, sequencing, and judgments are preserved wherever the fresh
inventory still supports them; deltas and corrections are called out per repo.

## Repo order (dependency order, unchanged from W114)

ggen → ggen-marketplace → ggen_igniter → ash_pplan → ash_a2a (park, no commits) → ash_surface → ferroplan → zcode-cli → gymact → wasm4pm → beam4pm (SKIP) → xaas

HEADs re-verified this sweep — all unchanged from W114:
ggen `feat/v26.10.5-release-cut@000bffb8f` · ggen-marketplace `feat/aaif-gcp-roadmap-v26.10.5@93895f808` ·
ggen_igniter `feat/adr-0010-gate-convention@7dbcdb3` · ash_pplan `fix/ggen-verify-header@414a393` ·
ash_surface `main@db5a889` · ferroplan `main@c037876` · zcode-cli `fix/v26926-preview-publish-typed-skip@7fc62da` ·
gymact `v26926/gymact-land-aloop-execution-kernel@d3eb5e8` · wasm4pm `fix/v26.9.30-ci-fmt-tsc@32deb59f6` ·
xaas `feat/playwright-surface@d1db2b03`

## Do-NOT-commit flags (W114 flags still standing, plus new)

| item | repo | reason |
|---|---|---|
| `ggen.lock`, `GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt`, `.clap-noun-verb/`, `.ggen_igniter/receipts/2026-10-06.jsonl` | xaas | same-day ggen-sh/lane runtime residue. `ggen.lock` commits only on coordinator confirmation it is a release product. STILL STANDING (all still untracked). |
| `artifacts/` | zcode-cli | today's build/test-run output. STILL STANDING. |
| `docs/thesis/` | ash_a2a | ownerless; park. STILL STANDING. |
| 5 pyc entries | ggen_igniter | W114 C0 pre-step **RESOLVED**: the 5 `__pycache__/*.pyc` entries are now staged **deletions** (`D `) and `.gitignore` gained `__pycache__/`. No pyc renames remain; the deletions ride in C1 via `git add test/fixtures/ash_manufacture_pack`. |
| **NEW** `ggen.lock` (untracked, mtime 13:18 today; `git log -- ggen.lock` empty — never committed) | ash_surface | same-day runtime residue, not a release product. Do not commit; gitignore or delete. |
| **NEW** 24 untracked court/specimen tests (`test/ash_a2a_*`, `test/ash_r2rml_*`, `test/audit_trail_*`, `test/notification_extension_*`, `test/ash_surface_{composition,transformer,verifier,igniter_idempotence,spark_parity,info_parity}*_court*`, `test/aex_spark_dead_surface_court.exs`) + `fixture/burn_in/` (15 files, mtime today 13:xx) | ash_surface | same-day sync-installer lane outputs. Courts reference `fixture/composition_specimens/` which **does not exist on disk** — committing tests without specimens yields a red suite. Park pending lane-owner confirmation; then land as one `test(courts): sync-installer specimen courts + burn_in fixtures` commit together with `fixture/`. |
| **HAZARD CHECK — RESOLVED (negative finding)** | ash_surface | **No `lib/ash_a2a/` or `lib/ash_r2rml/` untracked dirs exist** (`git status --untracked-files=all -- lib/` shows only `lib/ash_surface/a2a_bridge.ex`). The feared sync-installer lib-dump is absent. |
| `_build-lane*` / `_build` dirs | all repos | none in any porcelain output. Clean. |
| beam4pm | — | SKIPPED per W114 (read-only-check subject; not a convergence output). |

## 1. ggen (unchanged from W114 — 8 files)

**C1 `chore(release): cut ggen v26.10.6 release metadata`**
```bash
git add .claude-plugin/marketplace.json .specify/repo-facts.ttl Cargo.lock Cargo.toml \
  crates/ggen-engine/Cargo.toml crates/pm4pytest-cli/Cargo.toml docs/CHANGELOG.md ggen.toml
```

## 2. ggen-marketplace (2 → 5 files; NEW files landed since W114)

**C1 `chore(release): v26.10.6 marketplace catalog + changelog closure`**
```bash
git add CHANGELOG.md marketplace.active.toml
```

**C2 `feat(ash-extension-pack): spark-dead-surface gate + ontology/template updates`** (NEW)
```bash
git add packs/ash-extension-pack/gates/120_spark_dead_surface.rq \
  packs/ash-extension-pack/ontology.ttl packs/ash-extension-pack/templates/extension.ex.tmpl
```
Pairs with the parked ash_surface specimen courts + `fixture/burn_in/` (same render family);
when the courts un-park, land C2's consumers with them.

## 3. ggen_igniter (61 → 66 lines; W114 C1–C4 preserved with deltas)

**C1 `feat(pack): promote ash-manufacture-pack from test fixture to canonical priv/ggen pack`**
```bash
git add priv/ggen/ash-manufacture-pack test/fixtures/ash_manufacture_pack
```
covers all 22 non-pyc rename entries, the 2 RM content edits, and the 5 staged pyc deletions
(C0 complete — deletions land here).

**C2 `feat(gates): pack-catalog/gate-verify/verify-mutation support for the promoted pack`** — W114 add-list verbatim, all 8 files still modified:
```bash
git add lib/ggen_igniter/pack_catalog.ex lib/ggen_igniter/gate_verify.ex \
  lib/ggen_igniter/verify_mutation.ex lib/ggen_igniter/render/tera_wasm.ex \
  lib/ggen_igniter/semantic_jira/sovereign_lease.ex lib/ggen_igniter/semantic_jira/transition_log.ex \
  lib/mix/tasks/ggen_igniter.verify.ex mix.exs
```
(mix.exs ride-along may split as its own `chore(release)`, per W114.)

**C3 `test(pack): realign tests to canonical pack location + ADR-0010 gate convention`**
```bash
git add test/ggen_igniter_agent_guard_test.exs test/ggen_igniter_ash_gen_core_alignment_test.exs \
  test/ggen_igniter_ash_manufacture_pack_test.exs test/ggen_igniter_ash_task_coverage_test.exs \
  test/ggen_igniter_gate_verify_test.exs test/ggen_igniter_package_ash_free_test.exs \
  test/ggen_igniter_packs_task_test.exs test/ggen_igniter_semantic_jira_sovereign_lease_test.exs \
  test/ggen_igniter_verify_mutation_test.exs test/mix/tasks/ggen_igniter_verify_task_test.exs \
  test/support/postgres_case.ex
```
(DELTA: W114's C3 listed 10 files; the fresh inventory adds
`test/ggen_igniter_semantic_jira_sovereign_lease_test.exs` — 11 files now.)

**C4 `docs(pack): ash-manufacture-pack promotion + ADR-0010 gate-convention docs`**
```bash
git add AGENTS.md CHANGELOG.md README.md docs/contributing/dev-setup.md \
  docs/contributing/testing.md docs/diataxis/how-to/verify-and-replay-a-pack.md \
  docs/integrations/ash/overview.md docs/status.md .gitignore
```
(DELTA: `.gitignore` (`__pycache__/` line) rides in C4 rather than the vanished C0.)

## 4. ash_pplan (unchanged from W114 — 1 file)

**C1 `docs(demo): update demonstration walkthrough`** — `git add docs/demonstration.md`

## 5. ash_a2a — NO COMMITS in plan body; see **W201 delta** below — `docs/thesis/` stays parked (per flag table).

## W201 delta — post-W153-v2 sanctioned fixes in ash_a2a (added 2026-10-06, integration lane W201)

Three sanctioned fixes landed in the ash_a2a working tree after this plan was written.
Fresh inventory, verbatim `git status --porcelain` (HEAD `07180bd3`):

```
 M lib/ash_a2a/authzen/client.ex
 M test/ash_a2a/command_bus_test.exs
 M test/test_helper.exs
?? docs/thesis/
```

Diff shape: `lib/ash_a2a/authzen/client.ex | 7 +++++--`,
`test/ash_a2a/command_bus_test.exs | 5 ++++--`, `test/test_helper.exs | 10 +++++++++-`
(3 files changed, 18 insertions(+), 4 deletions(-)).

**W201-A1 `test(infra): outbox sweep + machine-unique test naming in test_helper`** (test-infra group)
```bash
git add test/test_helper.exs
```

**W201-A2 `test(command-bus): timeout tag + 5s receive window in command_bus_test`** (test-infra group)
```bash
git add test/ash_a2a/command_bus_test.exs
```

**W201-A3 `fix(authzen): monotonic-time TTL in authzen client (fail-closed, W130)`** (authzen fail-closed fix group)
```bash
git add lib/ash_a2a/authzen/client.ex
```

Full inventory rows for the sequenced table:

| # | repo | commit | message | files |
|---|---|---|---|---|
| 8b | ash_a2a | W201-A1 | test(infra): outbox sweep + machine-unique test naming | 1 |
| 8c | ash_a2a | W201-A2 | test(command-bus): timeout tag + 5s receive window | 1 |
| 8d | ash_a2a | W201-A3 | fix(authzen): monotonic-time TTL (fail-closed, W130) | 1 |

Slot after row 8 (ash_pplan C1), before ash_surface C1, preserving dependency order.
`docs/thesis/` remains parked (flag table, unchanged).

Gate run (PATH asdf shims, MIX_ENV=test):
`mix test test/ash_a2a/command_bus_test.exs test/ash_a2a/enterprise/authzen_client_test.exs`
— run 1: 19/20 (1 failure, not reproduced); runs 2 and 3: **20 passed** each. Falsifier
candidate: the run-1 failure (test name unrecorded — log not captured) may be residual
flake; rerun to confirm before treating as standing.

## 6. ash_surface (55 → 87 lines; W114 C1–C5 preserved, new park + deltas)

**C1 `feat(a2a-bridge): ash_surface A2A bridge surface`**
```bash
git add lib/ash_surface/a2a_bridge.ex test/ash_surface/a2a_bridge_test.exs
```

**C2 `feat(conformance): IR codec vectors + cross-language digest parity v3`**
```bash
git add conformance/ test/js/ test/support/digest_parity_fixtures.ex docs/DEP_GRAPH.md
```

**C3 `feat(projector): expo/aria/js/live_view projector closure + runtime regen`**
```bash
git add .gitignore ggen.toml mix.exs lib/ash_surface.ex lib/ash_surface/compiler.ex \
  lib/ash_surface/mx_episode.ex lib/ash_surface/projector/expo.ex \
  lib/ash_surface/projectors/aria.ex lib/ash_surface/projectors/js.ex \
  priv/static/ash_surface_runtime.mjs priv/verifier/verify_closure_episode.py \
  scripts/bump_version.sh scripts/conformance_regen.exs scripts/README.md \
  docs/diataxis/reference/api.md docs/diataxis/tutorials/manifest-to-surface.md
```
(DELTA: `scripts/README.md` added vs W114.)

**C4 `test(ash-surface): realign test suite to projector/codec closure`**
```bash
git add test/ash_surface/
```
(24 modified .exs under test/ash_surface/, incl. the untracked a2a_bridge test if not consumed by C1.)

**C5 `docs: lane sjira receipts + doc/ notes`**
```bash
git add doc/ docs/sjira/
```
(mtimes 2026-10-03 / 2026-10-05 — stable, not same-day scratch; unchanged from W114 judgment.)

PARKED (do not add): `fixture/`, the 24 court/specimen tests, `ggen.lock` — see flag table.

## 6b. ferroplan (unchanged from W114 — 5 lines)

**C1 `chore(generated): refresh ferroplan-wasm registry artifact + ggen-v2 receipts`**
```bash
git add .ggen-v2/receipt-log.jsonl .ggen-v2/receipt.json \
  crates/ferroplan-wasm/.ggen-v2/receipt-log.jsonl crates/ferroplan-wasm/.ggen-v2/receipt.json \
  crates/ferroplan-wasm/registry/ferroplan_wasm.wasm
```

## 7. zcode-cli (unchanged from W114 — 18 lines)

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

## 8. gymact (unchanged from W114 — 7 files)

**C1 `feat(gyms): ggen/fastapi surface updates + v26.10.6 version closure`**
```bash
git add pyproject.toml src/gymact/__init__.py CHANGELOG.md README.md docs/reference.md \
  src/gymact/gyms/ggen.py src/gymact/surfaces/fastapi.py
```

## 9. wasm4pm (unchanged from W114 — 4 files)

**C1 `chore(release): wasm4pm version bump + ml scaling test + receipt-truth doc`**
```bash
git add package.json apps/wasm4pm/README.md \
  docs/explanation/prd_ard_receipt_truth_verification.md \
  packages/ml/src/__tests__/algorithm-selection-with-scaling.test.ts
```

## 10. beam4pm — SKIPPED per W114.

## 11. xaas (165 → 176 lines; W114 X1–X9 skeleton preserved, deltas below)

**W153-X1 `chore(release): v26.10.6 version closure + dep pins`** — unchanged:
```bash
git add VERSION CHANGELOG.md README.md mix.exs mix.lock config/config.exs config/dev.exs
```

**W153-X2 `feat(ash-surface): castle bridge contract/edges generation + surface runtime projection`**
```bash
git add lib/mix/tasks/xaas.ash_surface.ex lib/xaas/generated/ lib/xaas/bridges/ferroplan.ex \
  priv/ash_surface/ priv/semantic/ \
  docs/claude/diataxis/reference/generated-castle-bridge-errc.md \
  docs/claude/diataxis/reference/ash-configuration.md \
  docs/claude/diataxis/reference/http-api-surface.md
```

**W153-X3 `feat(witness): certified-receipt witness catalog + live surface`**
```bash
git add lib/xaas/witness/ lib/xaas_web/live/witness_live.ex \
  lib/xaas_web/a2a/next_read_ash_agent.ex priv/repo/migrations/20261006000000_repair_witness_certified_receipts.exs \
  test/xaas/witness/catalog_test.exs test/xaas_web/live/witness_live_test.exs
```
(DELTA: W114's X3 named only 2 of the 3 witness lib files by glob `lib/xaas/witness/` — the glob
also covers the modified `certified_receipt.ex` / `verification_key.ex`; migration added as NEW.)

**W153-X4 `feat(refusal-typing): typed refusal surface + negative court batteries`**
lib (W114 path-inferred attribution — coordinator confirms via `git diff` before staging):
`lib/xaas/castle.ex, lib/xaas/fabric/failure.ex, lib/xaas/sa2a/court.ex,
lib/xaas/security/finding.ex, lib/xaas/chicago/layer.ex`
plus igniter/marketplace refusal-adjacent DELTA files (NEW since W114):
`lib/xaas/igniter/pack_manifest.ex, lib/xaas/igniter/refusal_code.ex, lib/xaas/marketplace/pack.ex`
(1-line diffs each — refusal-code surface updates; confirm via `git diff` before staging.)
tests (verbatim):
`test/mix/tasks/xaas_refusal_render_test.exs,
test/xaas/actuation_refusal_negative_test.exs,
test/xaas/castle_refusal_negative_test.exs,
test/xaas/castle_refusal_negative_batch{2,3,4,5}_test.exs,
test/xaas/semantics/vkg_refusal_negative_test.exs,
test/xaas/boundary_limits_test.exs,
test/xaas_web/a2a/v1_protocol_test.exs,
test/xaas_web/endpoint_body_limit_test.exs,
test/xaas_web/plugs/require_internal_api_token_test.exs`

**W153-X5 `feat(playwright): e2e spec surface + CI workflow`**
```bash
git add e2e/ playwright.config.cjs .github/workflows/playwright-e2e.yml .github/workflows/ci_cd.yaml
```

**W153-X6 `test(xaas): bridge/gymact/witness-adjacent unit tests + bench updates`**
```bash
git add bench/ lib/xaas/operations/gymact_surface.ex \
  test/xaas/bridges/ test/xaas/operations/gymact_surface_test.exs \
  test/xaas/mix/ test/xaas/generated/ \
  test/mix/tasks/xaas_ingest_capability_receipts_test.exs
```
(DELTA: ingest-capability-receipts test added.)

**W153-X7 `fix(lib): remaining lib + config surface updates from convergence`** — residual lib/config/scripts files not claimed by X2–X6, verbatim:
`lib/xaas/accounts/token.ex, lib/xaas/actuation.ex, lib/xaas/a2a/agent.ex, lib/xaas/a2a/task.ex,
lib/xaas/application.ex, lib/xaas/autofde/status_parser.ex, lib/xaas/bridges/{ex4pm,graphlaw,pplan,registry}.ex,
lib/xaas/conference/{attendee,event,registration,session,speaker,sponsor,track}.ex,
lib/xaas/eds/falsifier.ex, lib/xaas/fabric.ex, lib/xaas/fabric/failure.ex *(if not staged in X4)*,
lib/xaas/fabric/planes/{actuation,evidence,law,process}.ex, lib/xaas/graphlaw/catalog.ex,
lib/xaas/operations/capability_liveness_receipt.ex, lib/xaas/ultracode/semantic_drive.ex,
lib/xaas/ultracode/semantic_drive/plan_next.ex,
lib/xaas_web/a2a/next_read_user_agent.ex, lib/xaas_web/a2a/zoe_event_simulation_agent.ex,
lib/xaas_web/controllers/health_controller.ex, lib/xaas_web/endpoint.ex,
lib/xaas_web/live/chicago/drill_down_live.ex, lib/xaas_web/live/marketplace_catalog_live.ex,
lib/xaas_web/live/marketplace_pplan_explorer_live.ex,
lib/xaas_web/live/system/{command_center_adapter,command_center_live}.ex,
lib/xaas_web/plugs/stripe_raw_body_reader.ex, lib/xaas_web/router.ex,
priv/courts/substitution_policy_court.exs, scripts/semantic_replay_task.exs,
lib/mix/tasks/{xaas.capability_coverage,xaas.fabric.redeploy,xaas.ingest_capability_receipts,
xaas.release_audit,xaas.release_snapshot.verify,xaas.run_validate,xaas.safe_generate_migrations,
xaas.self_digest,xaas.sjira.engineer_work,xaas.stop_court}.ex`

**W153-X8 `test(xaas): realign remaining test suite to v26.10.6 convergence`** — residual test files not claimed by X3/X4/X6, verbatim:
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
test/xaas/ultracode/{semantic_drive_anchor,semantic_drive_plan_next,semantic_jira_bridge}_test.exs,
test/xaas_web/a2a/zoe_event_simulation_agent_test.exs,
test/xaas_web/controllers/health_controller_test.exs,
test/xaas_web/live/{marketplace_catalog_live,marketplace_pplan_explorer_live}_test.exs,
test/xaas/ash_surface_{drift_guard,generator}_test.exs`

**W153-X9 `docs(sjira): v26.10.6 lane receipts + plans (incl. this plan)`**
```bash
git add docs/sjira/v26.10.6/
```

**W153-X10 `docs(sjira): v26.9.21/v26.9.22 loop/admit/shacl script updates`** (NEW — W114 missed these)
```bash
git add docs/sjira/v26.9.21/ docs/sjira/v26.9.22/
```
(admit.exs, sa2a_post_SJ-003 receipt, sa2a_loop.exs ×2, shacl.exs — historical wave scripts
touched by today's convergence; kept separate from X9 so the v26.10.6 receipt dir stays pure.)

## Sequenced execution table

| # | repo | commit | message | files |
|---|---|---|---|---|
| 1 | ggen | C1 | chore(release): cut ggen v26.10.6 release metadata | 8 |
| 2 | ggen-marketplace | C1 | chore(release): v26.10.6 marketplace catalog + changelog closure | 2 |
| 3 | ggen-marketplace | C2 | feat(ash-extension-pack): spark-dead-surface gate + ontology/template | 3 |
| 4 | ggen_igniter | C1 | feat(pack): promote ash-manufacture-pack to priv/ggen (incl. pyc deletions) | 27 |
| 5 | ggen_igniter | C2 | feat(gates): pack-catalog/gate-verify/verify-mutation | 8 |
| 6 | ggen_igniter | C3 | test(pack): realign tests to canonical pack | 11 |
| 7 | ggen_igniter | C4 | docs(pack): promotion + ADR-0010 docs + gitignore | 9 |
| 8 | ash_pplan | C1 | docs(demo): update demonstration walkthrough | 1 |
| 9 | ash_surface | C1 | feat(a2a-bridge): A2A bridge surface | 2 |
| 10 | ash_surface | C2 | feat(conformance): IR codec vectors + digest parity v3 | 15 |
| 11 | ash_surface | C3 | feat(projector): projector closure + runtime regen | 16 |
| 12 | ash_surface | C4 | test(ash-surface): realign test suite | 24 |
| 13 | ash_surface | C5 | docs: lane sjira receipts + doc/ notes | 2 dirs |
| 14 | ferroplan | C1 | chore(generated): wasm registry artifact + receipts | 5 |
| 15 | zcode-cli | C1 | feat(max-turns): max-turns config surface + tests | 10 |
| 16 | zcode-cli | C2 | docs: configuration/host/releasing/c4 closure | 8 |
| 17 | gymact | C1 | feat(gyms): surface updates + version closure | 7 |
| 18 | wasm4pm | C1 | chore(release): version bump + ml scaling test + doc | 4 |
| 19 | xaas | X1 | chore(release): version closure + dep pins | 7 |
| 20 | xaas | X2 | feat(ash-surface): castle bridge + runtime projection | ~13 |
| 21 | xaas | X3 | feat(witness): witness catalog + live surface + migration | 7 |
| 22 | xaas | X4 | feat(refusal-typing): refusal surface + negative courts | ~21 |
| 23 | xaas | X5 | feat(playwright): e2e specs + CI workflows | e2e/ + 3 |
| 24 | xaas | X6 | test(xaas): bridge/gymact tests + bench | ~11 |
| 25 | xaas | X7 | fix(lib): remaining lib surface updates | ~42 |
| 26 | xaas | X8 | test(xaas): realign remaining tests | ~34 |
| 27 | xaas | X9 | docs(sjira): v26.10.6 lane receipts (incl. this plan) | 1 dir |
| 28 | xaas | X10 | docs(sjira): v26.9.21/22 script updates | 5 |
| — | ash_a2a / beam4pm / ash_surface courts | — | parked / skipped per flag table | — |

## Verification (coordinator runs after commits)

```bash
for r in xaas ash_surface ggen ggen-marketplace ggen_igniter ash_pplan zcode-cli gymact ferroplan wasm4pm; do
  echo "== $r"; git -C /Users/sac/$r status --porcelain
done
# expected residue: only flagged/parked items —
#   xaas: ggen-sh scratch set, docs/sjira historical (none left after X10)
#   zcode-cli: artifacts/
#   ash_a2a: docs/thesis/
#   ash_surface: ggen.lock, fixture/, 24 court/specimen tests
#   beam4pm: untouched
```

## Receipt fields

- subject: W153 refresh of W114 plan; branch/HEADs cited per repo above (all HEADs unchanged from W114)
- transport failures: W114's `/Users/sac/beam4pm-read-only-check` note carried forward (path does not exist)
- standing: PLAN ONLY — no commits executed; every `git add` line is a coordinator command, not an executed action
- falsifier: coordinator's post-commit `git status --porcelain` sweep shows residue beyond the flagged/parked set, or a commit's file count diverges from the plan's count column

## W204 delta — post-W153-v2 lane landings (integration lane W204, 2026-10-06)

Fresh `git status --porcelain`: **209 lines** (152 M/R + 57 `??`) vs W153-v2's 176 —
net +33. All HEADs unchanged (xaas `feat/playwright-surface@d1db2b03`). No git mutations
performed; this section is plan-only like the rest.

### (1) Inventory diff vs W153-v2's xaas list

Files in the fresh porcelain **not claimed by any W153-v2 group** (would otherwise be missed):

- `lib/xaas_web/plugs/a2a_parse_floor.ex` (untracked, NEW) — W150
- `test/xaas/accounts/token_revocation_test.exs` (untracked, NEW)
- `test/xaas/castle_refusal_negative_batch6_test.exs` (untracked, NEW; X4 names only batch{2,3,4,5})
- `test/xaas/semantics/r2rml_refusal_test.exs` (untracked, NEW; X4 names only vkg_refusal_negative)
- `test/mix/tasks/xaas_stop_court_test.exs` (M; X6 lists only the ingest test, X8 does not list it)
- `test/xaas/topology_guard_test.exs`, `test/xaas/telemetry/ocel_ash_emitter_test.exs`,
  `test/xaas/sa2a/route_test.exs`, `test/xaas/sjira/ard_court_test.exs` (M; none in X8's verbatim list)
- `test/xaas/ultracode/semantic_replay_test.exs`,
  `test/xaas/ultracode/sj_program_registry_test.exs` (M; X8 lists only
  `{semantic_drive_anchor,semantic_drive_plan_next,semantic_jira_bridge}_test.exs`)
- `docs/claude/diataxis/explanation/architecture-overview.md` (M; X2 claims only the three
  `reference/` docs — explanation/ is unclaimed)

Everything else in the fresh porcelain falls inside an existing W153-v2 glob or verbatim
list (X1–X10); the per-group deltas below refine attribution within those groups.

### (2) New files → group placement

| file(s) | lane | W153-v2 group | note |
|---|---|---|---|
| `lib/xaas_web/plugs/a2a_parse_floor.ex` + `lib/xaas_web/endpoint.ex` (plug line + `length: 8_000_000`) | W150 | joins router/a2a side of **X7** (endpoint.ex already listed in X7; router.ex too) | verified diff: `plug(XaasWeb.Plugs.A2AParseFloor)` before `Plug.Parsers` |
| `lib/xaas_web/controllers/health_controller.ex` + `config/config.exs` `:ontop_endpoint` block | W174 | health group: X1 (config) + X7 (controller); keep the ontop config line and controller in the SAME commit | verified diff: config-gated Ontop sub-check, `skipped(:not_configured)` fail-closed |
| `test/xaas/ultracode/sj_program_registry_test.exs`, `semantic_replay_test.exs`, `semantic_drive_plan_next_test.exs`, `lib/xaas/ultracode/semantic_drive.ex`, `semantic_drive/plan_next.ex` | W161 | X7 (lib) + X8 (tests) | sensing/drive realignment |
| `e2e/chicago-pplan-deep.spec.cjs`, `e2e/witness.spec.cjs`, `e2e/global-setup.cjs`, `e2e/seed-witness.exs`, `playwright.config.cjs` (`PHX_SERVER`) | W100/W117/W187 | **X5** (`e2e/` glob + playwright.config.cjs) | |
| `test/xaas/autofde/status_parser_test.exs` + `lib/xaas/autofde/status_parser.ex` | W92 | X7 (lib) + X8 (test) | verified: regex now accepts composite labels + date ranges (W63 receipt) |
| render_refusal lib/mix tasks (`xaas.safe_generate_migrations.ex`, `xaas.release_audit.ex`, `xaas.self_digest.ex`, `xaas.ash_surface.ex`, `xaas.release_snapshot.verify.ex`, `xaas.stop_court.ex`) + `test/mix/tasks/xaas_refusal_render_test.exs` | W86/W106 | X7 (lib tasks) + X4 (test) | verified: `render_refusal/1` present in the named tasks |
| `test/xaas/ultracode/semantic_drive_anchor_test.exs` (+ `lib/xaas/ultracode/semantic_drive.ex`) | W116 | X8 + X7 | verified: rewritten to typed `REFUSED(descriptor_refused)` — anchor refusal is the lawful outcome post-AC-04 |
| `VERSION` | — | **X1** | already in X1 add-list |
| `test/xaas/ultracode/sj_program_registry_test.exs` ("registry_test") | W161 | **X8** (NEW to X8's list) | see (1) |
| `test/xaas/castle_refusal_negative_batch6_test.exs` + `test/xaas/semantics/r2rml_refusal_test.exs` | W185 | **X4** (NEW to X4's list, land when W185 lands) | if W185 is not landed at commit time, stage these in a trailing `test(refusal): batch6 + r2rml courts` commit rather than blocking X4 |

### (3) Suggested conventional commit messages per group (xaas only)

| group | message |
|---|---|
| X1 | `chore(release): v26.10.6 version closure + dep pins + ontop_endpoint config` |
| X2 | `feat(ash-surface): castle bridge contract/edges generation + surface runtime projection` (unchanged) |
| X3 | `feat(witness): certified-receipt witness catalog + live surface + migration` (unchanged) |
| X4 | `feat(refusal-typing): typed refusal surface + negative court batteries (incl. render_refusal tests, castle batch6, r2rml)` |
| X5 | `feat(playwright): e2e spec surface + CI workflow + PHX_SERVER config` |
| X6 | `test(xaas): bridge/gymact/witness-adjacent unit tests + bench updates` (unchanged) |
| X7 | `fix(lib): a2a parse floor, health ontop check, autofde parser regex, refusal render, remaining lib convergence` |
| X8 | `test(xaas): realign remaining test suite (sem registry/replay, anchor refusal pins, topology/telemetry/route/ard courts)` |
| X9/X10 | unchanged |

Note on X1/X7 split: the Ontop health check spans `config/config.exs` (X1) and
`health_controller.ex` (X7). Recommended: move the single `:ontop_endpoint` hunk into
X7 (or the whole controller+config pair into one `feat(health)` commit) so the feature
lands atomically — coordinator's call at staging time.

### (4) W191 do-not-commit list — CONFIRMED STILL STANDING

Spot-checked 3 flagged paths, all still untracked same-day scratch, `ggen.lock` still
never committed (`git log -- ggen.lock` empty):

- `ggen.lock` (untracked, mtime 11:55, no history)
- `GGEN-SH-AFTER-MIX-COMPILE.log` / `GGEN-SH-AFTER-PROOF.txt` (untracked, mtime 11:55)
- `.clap-noun-verb/` (untracked, ocel.json + receipts.jsonl, mtime 12:13)
- also still untracked: `.ggen_igniter/receipts/2026-10-06.jsonl` (mtime 12:42)
