# W225 Final Staging Sequences — 10 non-xaas repos, v26.10.6 convergence

Lane W225, 2026-10-06. Sources: fresh `git status --porcelain` per repo (this lane, read-only),
W191 DO-NOT-COMMIT/PARKED lists (`w191-final-hazards.md` — supersedes stale hazard lists),
W153-v2 commit grouping (`w153-commit-plan-v2.md`), W201 ash_a2a delta (folded into the
ash_a2a section). W153-v2/W191 conflicts resolved in favor of W191; each resolution is called
out. No git mutations performed by this lane.

Repo order (dependency order, from W153-v2/W114, unchanged):
ggen → ggen-marketplace → ggen_igniter → ash_pplan → ash_a2a → ash_surface → ferroplan →
zcode-cli → gymact → wasm4pm.

HEADs (re-verified this sweep):
ash_surface `main@db5a8899e` · ggen `feat/v26.10.5-release-cut@000bffb8f` ·
ggen-marketplace `feat/aaif-gcp-roadmap-v26.10.5@93895f808` ·
ggen_igniter `feat/adr-0010-gate-convention@7dbcdb3` · ash_pplan `fix/ggen-verify-header@414a393` ·
zcode-cli `fix/v26926-preview-publish-typed-skip@7fc62da` ·
gymact `v26926/gymact-land-aloop-execution-kernel@d3eb5e8` · ferroplan `main@c037876` ·
wasm4pm `fix/v26.9.30-ci-fmt-tsc@32deb59f6` · ash_a2a `feat/tck-vuln-hardening@07180bd3`

Legend per repo: every porcelain line is listed as STAGED (with owning commit), EXCLUDED
(DO-NOT-COMMIT), or PARKED. Line counts stated per repo.

---

## 1. ggen — 8 lines, all ` M `. No untracked. No hazards.

**C1 `chore(release): cut ggen v26.10.6 release metadata`**

| # | porcelain line | disposition |
|---|---|---|
| 1 | ` M .claude-plugin/marketplace.json` | STAGED → C1 |
| 2 | ` M .specify/repo-facts.ttl` | STAGED → C1 |
| 3 | ` M Cargo.lock` | STAGED → C1 |
| 4 | ` M Cargo.toml` | STAGED → C1 |
| 5 | ` M crates/ggen-engine/Cargo.toml` | STAGED → C1 |
| 6 | ` M crates/pm4pytest-cli/Cargo.toml` | STAGED → C1 |
| 7 | ` M docs/CHANGELOG.md` | STAGED → C1 |
| 8 | ` M ggen.toml` | STAGED → C1 |

```bash
git add .claude-plugin/marketplace.json .specify/repo-facts.ttl Cargo.lock Cargo.toml \
  crates/ggen-engine/Cargo.toml crates/pm4pytest-cli/Cargo.toml docs/CHANGELOG.md ggen.toml
git commit -F <msg-file>   # chore(release): cut ggen v26.10.6 release metadata
```

---

## 2. ggen-marketplace — 5 lines, all ` M `. No untracked. No hazards.

**C1 `chore(release): v26.10.6 marketplace catalog + changelog closure`**
**C2 `feat(ash-extension-pack): spark-dead-surface gate + ontology/template updates`**
(C2 pairs with the PARKED ash_surface specimen courts — when the courts un-park, C2's
consumers may land with them; until then C2 stands alone as gate/ontology surface.)

| # | porcelain line | disposition |
|---|---|---|
| 1 | ` M CHANGELOG.md` | STAGED → C1 |
| 2 | ` M marketplace.active.toml` | STAGED → C1 |
| 3 | ` M packs/ash-extension-pack/gates/120_spark_dead_surface.rq` | STAGED → C2 |
| 4 | ` M packs/ash-extension-pack/ontology.ttl` | STAGED → C2 |
| 5 | ` M packs/ash-extension-pack/templates/extension.ex.tmpl` | STAGED → C2 |

```bash
# C1
git add CHANGELOG.md marketplace.active.toml
# C2
git add packs/ash-extension-pack/gates/120_spark_dead_surface.rq \
  packs/ash-extension-pack/ontology.ttl packs/ash-extension-pack/templates/extension.ex.tmpl
```

---

## 3. ggen_igniter — 61 lines. No untracked. No DO-NOT-COMMIT (the 5 pyc deletions ARE
the deliverable — do not restore).

Porcelain: 16 ` M `, 5 `D ` (staged pyc deletions), 28 `R ` renames, 2 `RM ` renames-with-edits.

**C1 `feat(pack): promote ash-manufacture-pack from test fixture to canonical priv/ggen pack`**
covers the 28 `R ` renames + 2 `RM ` edits + 5 `D ` pyc deletions.
**C2 `feat(gates): pack-catalog/gate-verify/verify-mutation support for the promoted pack`**
**C3 `test(pack): realign tests to canonical pack location + ADR-0010 gate convention`**
**C4 `docs(pack): ash-manufacture-pack promotion + ADR-0010 gate-convention docs`**

| # | porcelain line | disposition |
|---|---|---|
| 1 | ` M .gitignore` | STAGED → C4 |
| 2 | ` M AGENTS.md` | STAGED → C4 |
| 3 | ` M CHANGELOG.md` | STAGED → C4 |
| 4 | ` M docs/contributing/dev-setup.md` | STAGED → C4 |
| 5 | ` M docs/contributing/testing.md` | STAGED → C4 |
| 6 | ` M docs/diataxis/how-to/verify-and-replay-a-pack.md` | STAGED → C4 |
| 7 | ` M docs/integrations/ash/overview.md` | STAGED → C4 |
| 8 | ` M docs/status.md` | STAGED → C4 |
| 9 | ` M lib/ggen_igniter/gate_verify.ex` | STAGED → C2 |
| 10 | ` M lib/ggen_igniter/pack_catalog.ex` | STAGED → C2 |
| 11 | ` M lib/ggen_igniter/render/tera_wasm.ex` | STAGED → C2 |
| 12 | ` M lib/ggen_igniter/semantic_jira/sovereign_lease.ex` | STAGED → C2 |
| 13 | ` M lib/ggen_igniter/semantic_jira/transition_log.ex` | STAGED → C2 |
| 14 | ` M lib/ggen_igniter/verify_mutation.ex` | STAGED → C2 |
| 15 | ` M lib/mix/tasks/ggen_igniter.verify.ex` | STAGED → C2 |
| 16 | ` M mix.exs` | STAGED → C2 |
| 17–21 | `D  test/fixtures/ash_manufacture_pack/bin/__pycache__/{citation_check,conformance,drift_check,evidence_check,receipt}.cpython-314.pyc` | STAGED → C1 (deletions are the point) |
| 22–49 | 28 `R ` renames `test/fixtures/ash_manufacture_pack/** -> priv/ggen/ash-manufacture-pack/**` | STAGED → C1 |
| 50 | `RM test/fixtures/ash_manufacture_pack/bin/day_zero.sh -> priv/ggen/ash-manufacture-pack/bin/day_zero.sh` | STAGED → C1 |
| 51 | `RM test/fixtures/ash_manufacture_pack/README.md -> priv/ggen/ash-manufacture-pack/README.md` | STAGED → C1 |
| 52 | ` M test/ggen_igniter_agent_guard_test.exs` | STAGED → C3 |
| 53 | ` M test/ggen_igniter_ash_gen_core_alignment_test.exs` | STAGED → C3 |
| 54 | ` M test/ggen_igniter_ash_manufacture_pack_test.exs` | STAGED → C3 |
| 55 | ` M test/ggen_igniter_ash_task_coverage_test.exs` | STAGED → C3 |
| 56 | ` M test/ggen_igniter_gate_verify_test.exs` | STAGED → C3 |
| 57 | ` M test/ggen_igniter_package_ash_free_test.exs` | STAGED → C3 |
| 58 | ` M test/ggen_igniter_packs_task_test.exs` | STAGED → C3 |
| 59 | ` M test/ggen_igniter_semantic_jira_sovereign_lease_test.exs` | STAGED → C3 |
| 60 | ` M test/ggen_igniter_verify_mutation_test.exs` | STAGED → C3 |
| 61 | ` M test/mix/tasks/ggen_igniter_verify_task_test.exs` | STAGED → C3 |
| — | ` M test/support/postgres_case.ex` | STAGED → C3 |

(Note: rows 52–61 + postgres_case = 11 test files, matching W153-v2's C3 delta.)

```bash
# C1 — renames+deletions already staged; `git add` both dirs to catch RM content edits
git add priv/ggen/ash-manufacture-pack test/fixtures/ash_manufacture_pack
# C2
git add lib/ggen_igniter/pack_catalog.ex lib/ggen_igniter/gate_verify.ex \
  lib/ggen_igniter/verify_mutation.ex lib/ggen_igniter/render/tera_wasm.ex \
  lib/ggen_igniter/semantic_jira/sovereign_lease.ex lib/ggen_igniter/semantic_jira/transition_log.ex \
  lib/mix/tasks/ggen_igniter.verify.ex mix.exs
# C3
git add test/ggen_igniter_agent_guard_test.exs test/ggen_igniter_ash_gen_core_alignment_test.exs \
  test/ggen_igniter_ash_manufacture_pack_test.exs test/ggen_igniter_ash_task_coverage_test.exs \
  test/ggen_igniter_gate_verify_test.exs test/ggen_igniter_package_ash_free_test.exs \
  test/ggen_igniter_packs_task_test.exs test/ggen_igniter_semantic_jira_sovereign_lease_test.exs \
  test/ggen_igniter_verify_mutation_test.exs test/mix/tasks/ggen_igniter_verify_task_test.exs \
  test/support/postgres_case.ex
# C4
git add AGENTS.md CHANGELOG.md README.md docs/contributing/dev-setup.md \
  docs/contributing/testing.md docs/diataxis/how-to/verify-and-replay-a-pack.md \
  docs/integrations/ash/overview.md docs/status.md .gitignore
```

---

## 4. ash_pplan — 1 line.

**AMBIGUITY FLAG (coordinator):** W153-v2's C1 listed 2 files
(`docs/demonstration.md` + `lib/ash_pplan/providers/a2a.ex`). Fresh porcelain shows ONLY
`docs/demonstration.md` — the a2a provider mod is gone from the working tree (landed in an
earlier commit or reverted after W153-v2 was written). Commit only what exists.

**C1 `docs(demo): update demonstration walkthrough`**

| # | porcelain line | disposition |
|---|---|---|
| 1 | ` M docs/demonstration.md` | STAGED → C1 |

```bash
git add docs/demonstration.md
```

---

## 5. ash_a2a — 4 lines (3 ` M ` + 1 `?? `). W201 delta folded; W153-v2's "NO COMMITS"
body is superseded by the W201 delta, as W153-v2 itself directs.

**W201-A1 `test(infra): outbox sweep + machine-unique test naming in test_helper`**
**W201-A2 `test(command-bus): timeout tag + 5s receive window in command_bus_test`**
**W201-A3 `fix(authzen): monotonic-time TTL in authzen client (fail-closed, W130)`**

| # | porcelain line | disposition |
|---|---|---|
| 1 | ` M lib/ash_a2a/authzen/client.ex` | STAGED → W201-A3 |
| 2 | ` M test/ash_a2a/command_bus_test.exs` | STAGED → W201-A2 |
| 3 | ` M test/test_helper.exs` | STAGED → W201-A1 |
| 4 | `?? docs/thesis/` | PARKED (ownerless LaTeX thesis, mtime Oct 5, no owning lane; W191+W153 both park) |

```bash
git add test/test_helper.exs            # W201-A1
git add test/ash_a2a/command_bus_test.exs  # W201-A2
git add lib/ash_a2a/authzen/client.ex   # W201-A3
```

W201 gate record (standing): `mix test test/ash_a2a/command_bus_test.exs
test/ash_a2a/enterprise/authzen_client_test.exs` — runs 2 and 3: 20 passed each; run-1 single
failure not reproduced (possible flake; rerun before staging if it recurs).

---

## 6. ash_surface — 89 lines: 52 ` M ` + 6 `?? ` dirs/files + 31 top-level court/specimen
`?? ` files.

**C1 `feat(a2a-bridge): ash_surface A2A bridge surface`**
**C2 `feat(conformance): IR codec vectors + cross-language digest parity v3`**
**C3 `feat(projector): expo/aria/js/live_view projector closure + runtime regen`**
**C4 `test(ash-surface): realign test suite to projector/codec closure`**
**C5 `docs: lane sjira receipts + doc/ notes`**

| # | porcelain line | disposition |
|---|---|---|
| 1 | ` M .github/workflows/manufacture.yml` | STAGED → C3 |
| 2 | ` M .gitignore` | STAGED → C3 |
| 3 | ` M CHANGELOG.md` | STAGED → C3 |
| 4 | ` M conformance/js/known_divergences.mjs` | STAGED → C2 |
| 5 | ` M conformance/js/replay.mjs` | STAGED → C2 |
| 6 | ` M conformance/MANIFEST.json` | STAGED → C2 |
| 7 | ` M conformance/vectors/ir_codec.json` | STAGED → C2 |
| 8 | ` M conformance/vectors/surface_contract_digest.json` | STAGED → C2 |
| 9 | ` M docs/DEP_GRAPH.md` | STAGED → C2 |
| 10 | ` M docs/diataxis/reference/api.md` | STAGED → C3 |
| 11 | ` M docs/diataxis/tutorials/manifest-to-surface.md` | STAGED → C3 |
| 12 | ` M ggen.toml` | STAGED → C3 |
| 13 | ` M lib/ash_surface.ex` | STAGED → C3 |
| 14 | ` M lib/ash_surface/compiler.ex` | STAGED → C3 |
| 15 | ` M lib/ash_surface/mx_episode.ex` | STAGED → C3 |
| 16 | ` M lib/ash_surface/projector/expo.ex` | STAGED → C3 |
| 17 | ` M lib/ash_surface/projectors/aria.ex` | STAGED → C3 |
| 18 | ` M lib/ash_surface/projectors/js.ex` | STAGED → C3 |
| 19 | ` M mix.exs` | STAGED → C3 |
| 20 | ` M priv/static/ash_surface_runtime.mjs` | STAGED → C3 |
| 21 | ` M priv/verifier/verify_closure_episode.py` | STAGED → C3 |
| 22 | ` M scripts/bump_version.sh` | STAGED → C3 |
| 23 | ` M scripts/conformance_regen.exs` | STAGED → C3 |
| 24 | ` M scripts/README.md` | STAGED → C3 |
| 25–46 | 22 ` M test/ash_surface/*.exs` (compiler, digest_parity_fixture, digest, ir_codec_coverage, ir_codec_golden, ir_codec, ir_struct, manifest_serializer, mx_closed_loop_deep, mx_closed_loop_episode, mx_episode_compose, projector/expo_receipts_hash, projector/expo_schemas, projectors_coverage, projectors/aria_projector, projectors/js_projector, projectors/live_view_states, projectors/live_view, version_sync) | STAGED → C4 |
| 47–55 | 9 ` M test/js/*` (digest_cross_language_v2, digest_cross_language_v3, digest_cross_language, e2e_hermetic, fixtures/digest_cross_language_fixtures.json, ir_projector_deep, receipts_primitives, version_sync, zoela_mx_consumer_fixture) | STAGED → C2 |
| 56 | ` M test/support/digest_parity_fixtures.ex` | STAGED → C2 |
| 57 | `?? lib/ash_surface/a2a_bridge.ex` | STAGED → C1 |
| 58 | `?? test/ash_surface/a2a_bridge_test.exs` | STAGED → C1 (EXCEPTION: nested bridge test, NOT a specimen court — W191) |
| 59 | `?? doc/` | STAGED → C5 (exdoc notes, mtime Oct 3 — stable; W114/W153 judgment; NOTE W191 flagged `doc/` as build output for ash_surface — see AMBIGUITY FLAG A1) |
| 60 | `?? docs/sjira/` | STAGED → C5 (lane receipts) |
| 61 | `?? fixture/` | PARKED (with the courts, below) |
| 62–92 | 31 `?? test/*_court*.exs` + `test/ash_a2a_composition_test.exs` (the aex_spark_dead_surface / ash_a2a_* / ash_r2rml_* / ash_surface_* / audit_trail_* / notification_extension_* specimen families; exact list in w191-final-hazards.md) | PARKED (ownerless; courts reference `fixture/composition_specimens/` which does not exist on disk — committing yields a red suite) |

```bash
# C1
git add lib/ash_surface/a2a_bridge.ex test/ash_surface/a2a_bridge_test.exs
# C2
git add conformance/ test/js/ test/support/digest_parity_fixtures.ex docs/DEP_GRAPH.md
# C3
git add .gitignore ggen.toml mix.exs lib/ash_surface.ex lib/ash_surface/compiler.ex \
  lib/ash_surface/mx_episode.ex lib/ash_surface/projector/expo.ex \
  lib/ash_surface/projectors/aria.ex lib/ash_surface/projectors/js.ex \
  priv/static/ash_surface_runtime.mjs priv/verifier/verify_closure_episode.py \
  scripts/bump_version.sh scripts/conformance_regen.exs scripts/README.md \
  docs/diataxis/reference/api.md docs/diataxis/tutorials/manifest-to-surface.md
# C4
git add test/ash_surface/
# C5
git add doc/ docs/sjira/
```

**AMBIGUITY FLAG A1 (coordinator):** W191 classifies `doc/` (ash_surface) as DO-NOT-COMMIT
exdoc build output; W153-v2 C5 commits `doc/` as stable notes (mtime Oct 3). Both cannot
stand. Default here: follow W153-v2's commit with the coordinator inspecting `doc/` content
first — commit only hand-written notes, exclude `.build`/HTML artifacts. If inspection is
skipped, prefer W191 (exclude `doc/`).
**Note:** W153-v2 also flagged `ggen.lock` (untracked) at ash_surface root — absent from
fresh porcelain (removed since). Resolved by observation.

---

## 7. ferroplan — 5 lines. CONFLICT RESOLVED IN FAVOR OF W191 (supersedes W153-v2 6b).

W153-v2 6b committed the `.ggen-v2/` receipts and the wasm blob; W191 explicitly classifies
both as DO-NOT-COMMIT (checkout noise / build artifact). W191 wins.

**Net: ferroplan has NO commit this cycle.**

| # | porcelain line | disposition |
|---|---|---|
| 1 | ` M .ggen-v2/receipt-log.jsonl` | EXCLUDED (ggen scratch receipt, mtime Oct 1 — W191) |
| 2 | ` M .ggen-v2/receipt.json` | EXCLUDED (same) |
| 3 | ` M crates/ferroplan-wasm/.ggen-v2/receipt-log.jsonl` | EXCLUDED (same) |
| 4 | ` M crates/ferroplan-wasm/.ggen-v2/receipt.json` | EXCLUDED (same) |
| 5 | `?? crates/ferroplan-wasm/registry/ferroplan_wasm.wasm` | EXCLUDED (3.5 MB compiled WASM build artifact, mtime Oct 6 — W191; committed registry metadata ARTIFACTS.sha256 + capability-registry.json are already in HEAD and unchanged) |

```bash
# no git add; leave working tree dirty or restore the .ggen-v2 mods — never commit
```

---

## 8. zcode-cli — 18 lines: 13 ` M ` + 5 `?? `.

**C1 `feat(max-turns): subagent max-turns config surface + expert-strategy config tests`**
**C2 `docs: configuration/host-integration/releasing/c4 doc closure`**

| # | porcelain line | disposition |
|---|---|---|
| 1 | ` M AGENTS.md` | STAGED → C2 |
| 2 | ` M docs/c4-zcode-cli-xaas.md` | STAGED → C2 |
| 3 | ` M docs/CONFIGURATION.md` | STAGED → C2 |
| 4 | ` M docs/CONFIGURATION.zh-CN.md` | STAGED → C2 |
| 5 | ` M docs/HOST_INTEGRATION.md` | STAGED → C2 |
| 6 | ` M docs/RELEASING.md` | STAGED → C2 |
| 7 | ` M HANDWRITTEN.md` | STAGED → C2 |
| 8 | ` M README.md` | STAGED → C2 |
| 9 | ` M scripts/sync-runtime.ts` | STAGED → C1 |
| 10 | ` M src/launcher.ts` | STAGED → C1 |
| 11 | ` M src/max-turns.ts` | STAGED → C1 |
| 12 | ` M test/max-turns.test.ts` | STAGED → C1 |
| 13 | ` M test/sync-runtime-anchor-drift.test.ts` | STAGED → C1 |
| 14 | `?? test/expert-strategy-config.test.ts` | STAGED → C1 (pairs with max-turns.test.ts — deliberate deliverable, W191) |
| 15 | `?? test/fixtures/max-turns/setting-subagent-100.json` | STAGED → C1 |
| 16 | `?? test/fixtures/max-turns/setting-subagent-invalid.json` | STAGED → C1 |
| 17 | `?? test/fixtures/max-turns/setting-subagent-missing.json` | STAGED → C1 |
| 18 | `?? artifacts/` | EXCLUDED (same-day agent scratch, mtime Oct 6 12:12 — W191+W153) |

```bash
# C1
git add src/max-turns.ts src/launcher.ts scripts/sync-runtime.ts \
  test/max-turns.test.ts test/sync-runtime-anchor-drift.test.ts \
  test/expert-strategy-config.test.ts test/fixtures/max-turns/
# C2
git add AGENTS.md HANDWRITTEN.md README.md docs/CONFIGURATION.md docs/CONFIGURATION.zh-CN.md \
  docs/HOST_INTEGRATION.md docs/RELEASING.md docs/c4-zcode-cli-xaas.md
```

---

## 9. gymact — 7 lines, all ` M `. No untracked. No hazards.

**C1 `feat(gyms): ggen/fastapi surface updates + v26.10.6 version closure`**

| # | porcelain line | disposition |
|---|---|---|
| 1 | ` M CHANGELOG.md` | STAGED → C1 |
| 2 | ` M docs/reference.md` | STAGED → C1 |
| 3 | ` M pyproject.toml` | STAGED → C1 |
| 4 | ` M README.md` | STAGED → C1 |
| 5 | ` M src/gymact/__init__.py` | STAGED → C1 |
| 6 | ` M src/gymact/gyms/ggen.py` | STAGED → C1 |
| 7 | ` M src/gymact/surfaces/fastapi.py` | STAGED → C1 |

```bash
git add pyproject.toml src/gymact/__init__.py CHANGELOG.md README.md docs/reference.md \
  src/gymact/gyms/ggen.py src/gymact/surfaces/fastapi.py
```

---

## 10. wasm4pm — 26 lines, all ` M `. No untracked. No hazards.
(W191 said 28; fresh count is 26 — package.json bump set unchanged in kind, count drift
noted, no path-level conflict.)

**C1 `chore(release): wasm4pm version bump + ml scaling test + receipt-truth doc`**

| # | porcelain line | disposition |
|---|---|---|
| 1–24 | 24 ` M */package.json` + ` M package.json` across root, apps/wasm4pm, examples/{web-dashboard,zoe-la}, lab, packages/{agents,cognition,config,contracts,engine,kernel,ml,noun-verb,observability,planner,supabase,testing}, playground, tests/{archive,proof}, wasm4pm, wasm4pm/validators | STAGED → C1 (version bump wave) |
| 25 | ` M apps/wasm4pm/README.md` | STAGED → C1 |
| 26 | ` M docs/explanation/prd_ard_receipt_truth_verification.md` | STAGED → C1 |
| — | ` M packages/ml/src/__tests__/algorithm-selection-with-scaling.test.ts` | STAGED → C1 (counted in the 26) |

```bash
git add package.json apps/wasm4pm/README.md \
  docs/explanation/prd_ard_receipt_truth_verification.md \
  packages/ml/src/__tests__/algorithm-selection-with-scaling.test.ts \
  '**/package.json'
# NOTE: '**/package.json' glob also picks up unchanged package.json files — git add is a
# no-op for them, so the staged set stays exactly the 24 modified ones. Alternatively add
# each modified path explicitly from the table.
```

---

## Ambiguity flags for coordinator

1. **ash_surface `doc/`** — W191 (DO-NOT-COMMIT build output) vs W153-v2 C5 (commit as
   stable notes). Plan above stages it in C5 but requires inspection; prefer W191 exclusion
   if unexamined.
2. **ash_pplan a2a provider file** — W153-v2 lists `lib/ash_pplan/providers/a2a.ex`; fresh
   porcelain does not. Committed elsewhere or reverted; only `docs/demonstration.md` staged.
3. **ash_surface courts + `fixture/`** — parked per W191 AND W153-v2 (they agree), but the
   ggen-marketplace C2 commit (gate/ontology/template) lands while its test consumers remain
   parked. Acceptable (gate surface is self-contained) but the coordinator should record
   that pairing debt.
4. **wasm4pm count** — W191 said 28 modified files; fresh porcelain shows 26. No path-level
   disagreement found; counted from live output.
5. **ggen `docs/CHANGELOG.md`** — W191 said "docs" generically; fresh porcelain shows exactly
   8 files including `docs/CHANGELOG.md`; staged as listed.

## Verification record

## W241 verified current

## Verification record

Commands run (read-only): `git -C <repo> status --porcelain | sort` for all 10 repos +
HEAD `rev-parse`; reads of w191-final-hazards.md and w153-commit-plan-v2.md. No git
mutations performed. Falsifier: post-execution `git status --porcelain` per repo must show
only EXCLUDED/PARKED rows from the tables above.
