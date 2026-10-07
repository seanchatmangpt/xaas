# v26.10.6 Milestone Closure Plan

Wave-2 lane W65. Source of truth: receipts under
`docs/sjira/v26.10.6/plans/` (vectors 1–6, r1–r9/r11, x1–x8, w30–w58).
Integration base: `feat/playwright-surface` @ `d1db2b03` (`_FRONTIER.md`).
This plan contains ONLY closure work — no new features, no surface expansion.

---

## 1. Current Unfinished Surface Inventory

Itemized from vector1 (fenced gates), vector2 (refusal gaps), vector3
(ignored suites), vector4 (gen parity), x1/x1b/x3 (playwright/web), x8
(generator), r4–r11 (fleet), w30/w51 (integration state). Statuses are
receipt evidence only.

| # | file path | identifier | status | blocking dependency | source |
|---|---|---|---|---|---|
| 1 | `lib/xaas_web/a2a/next_read_ash_agent.ex` (untracked) | `XaasWeb.A2A.NextReadAshAgent` (`use AshA2A.Protocol.Agent`) | **RESOLVED (receipt)** — ash_a2a pin advanced to `86214551` (mix.lock verified 2026-10-06), compile green; `AshA2A.Protocol.*` present at pin | closed by pin advance (P0-2 path); see also w35/w51 for the original gap | w51 → pin receipt (mix.lock `86214551`) |
| 2 | `lib/xaas/operations/gymact_surface.ex` (untracked) | TokenMissingError `:232` missing `)` | **RESOLVED (receipt)** — W42 gymact_surface landed; court run 9/9 green | none — file settled + compiles; court receipt W42 | w42 |
| 3 | `lib/xaas/bridges/pplan.ex` | undefined `AshPPlan.Continuation` / `resume_continuation` / `capture_continuation` (:98,102,129) | **RESOLVED (receipt)** — W41 facade rewrite landed; court 5/5 green; ash_pplan pin since advanced (`b9da1ad` → `5f10c979`, mix.lock verified) | closed by facade rewrite against pinned API; regression courts green | w41 |
| 4 | `lib/xaas_web/live/marketplace_catalog_live.ex:21-34` | `TODO(ash_surface)` π_LiveView wiring | fenced, text STALE (w338: dep blocker resolved by `mix.exs:115` all-envs path dep; TODO still cites retired ash_a2a ref `3325032` while mix.lock pins `86214551` which ships `AshA2A.Protocol.*`) | TODO text correction only; remaining π wiring steps are surface work, out of closure scope | vector1, w338 |
| 5 | `lib/xaas/vault.ex:10-25` | committed `CLOAK_KEY` placeholder | **RESOLVED (receipt)** — OS-17 landed: `Xaas.Vault.init/1` prod branch returns `{:stop, {:cloak_key_missing, :prod_refuses_placeholder_key}}` (fail-closed; dev/test unchanged); guard tests 4/4 incl. source pin (w349 receipt + w393 wiring trace; CHANGELOG entry landed) | none — OS-17 closed | vector1, w349, w393 |
| 6 | `lib/mix/tasks/xaas.ingest_capability_receipts.ex:55-59` | `authorize?: false` ingest bypass | **RESOLVED (receipt)** — task now `authorize?: true` with `Xaas.SystemAuthority(:oban_scheduler)` actor; real `:ingest` policy on the resource admits only SystemActor/service, deny floor intact (w338 disk-verified) | none | vector1, w337, w338 |
| 7 | `lib/xaas/operations/capability_liveness_receipt.ex:49-56` | Monitor/ingest step unscheduled | **RESOLVED (permanent-fence)** — deliberate: ingest input is a sibling-repo artifact; task fail-closes via Mix.raise when absent; call sites are on-demand only (w353 disposition; Analyze half runs on the `*/15` cron) | reopen only if a CI stage after `weaver-live-matrix.sh` appears | vector1, w353 |
| 8 | `lib/xaas_web/live/system/command_center_adapter.ex:81`, `live/chicago/drill_down_live.ex:68,408` | `Code.ensure_loaded?` soft-gates | **RESOLVED (by-test)** — both guards target core own modules (`Xaas.Chicago`/`Xaas.Chicago.View`, landed); presence pin test `test/xaas/chicago/presence_pin_test.exs` (w359) makes the `{:refused,...}` branches provably dead; stale moduledoc premise noted in w353 | none — pin test is the closure | vector1, w353, w359 |
| 9 | `lib/xaas/ultracode/semantic_jira_bridge.ex:11-13` | ggen_igniter optional-dep gate | **RESOLVED (permanent-fence)** — dep pinned hex `{:ggen_igniter, "~> 26.10.1"}` (`mix.exs:226`); documented post-G1 fail-closed contract; row criterion ("permanent if dep is permanent") met (w338) | none | vector1, w338 |
| 10 | `test/xaas/chicago/seller/seller_live_test.exs:308` | R6 `/chicago/seller` un-skip marker | **RESOLVED (receipt)** — skip marker deleted 2026-10-06 (coordinator); in-file note at `:307`, route registered at `router.ex:62` | none — route pre-existed; un-skip was pure code closure | vector1, vector3, x3 |
| 11 | `lib/xaas_web/endpoint.ex:71-77` | no explicit `:length` on Plug.Parsers (implicit 8 MiB) | **RESOLVED (receipt)** — W22: explicit `length: 8_000_000` landed (`endpoint.ex:74`, disk-verified) + boundary tests (`endpoint_body_limit_test.exs`, typed 413) | none | vector5, w22 |
| 12 | `priv/ash_surface/*.json` + `.mjs` | `generatorIdentity: ash_surface:v26.10.1` vs ash_surface HEAD `db5a889` past 26.10.1 | **RESOLVED (receipt)** — `surface_contract.json` reads `generatorIdentity: ash_surface:v26.10.6` (w73 + w338 disk re-verify); digests recorded in `priv/semantic/generated/MANIFEST.json` (w336) | none | vector6, x8, w73, w336 |
| 13 | `lib/xaas/castle.ex` + 6 of 7 castle-bridge outputs | `GGEN:XAAS_CASTLE_CONTRACT` injection absent at HEAD; outputs untracked/unignored | **RESOLVED (receipt)** — W36: regeneration run + deterministic (byte-stable re-render verified); injection present at `castle.ex:109-115` (disk-verified). Remaining commit/drift-gate wiring tracked separately as P2-1/P2-2 | commit of outputs + CI gate = P2-1/P2-2 (open, coordinator) | vector4, w36 |
| 14 | ash_surface root `ggen.toml` sync | 15 generated files exist nowhere (uncommitted, unignored) | **RESOLVED (receipt)** — W37: doctrine=excluded decision landed; generated sync outputs gitignored in ash_surface | none — exclusion is the typed decision; no commit/gate required | vector4, w37 |
| 15 | `mix xaas.ash_surface` → `priv/ash_surface/*` | parity NOT VERIFIED (mix excluded in vector4) | **RESOLVED (receipt)** — W73: regenerated under v26.10.6 (`surface_contract.json` `generatorIdentity: ash_surface:v26.10.6`, disk-verified) + drift guard green | CI leg wiring remains P2-2 (open, coordinator) | vector4, x8 gap 3, w73 |
| 16 | `priv/ontop/xaas-mapping.generated.ttl` | generator not located | **OPERATOR-DECISION (w353)** — re-sweep confirms w85: zero producers anywhere; single historical commit `28936f48`; no header/provenance. Option B recommended (delete — zero code consumers); Option A (adopt + header annotation at next regen) if a consumer surfaces | operator delete-vs-adopt call | vector4, w353 |
| 17 | `lib/xaas/generated/zcode_event_registry.ex`, `sa2a_bridge_*.ex` | headers name mix-only generators; no CI drift gate | untested | run generators + diff gate | vector4 |
| 18 | `e2e/*.spec.cjs` (15 files, incl. 9 new PW specs) | full `npx playwright test` green run | **PARTIAL (receipt)** — W70 executed 79 PW specs green post-compile-fix; final full-suite closure receipt W118 pending (last-mile full `npx playwright test` run + filed receipt) | W118: full green run + receipt on disk | w30, w70, x1b |
| 19 | `~/.zcode/cli/plugins/cache/xaas-fabric-marketplace/xaas-fabric/26.9.17/` | xaas-fabric plugin pinned 26.9.17 vs moved xaas side | drifting | re-render via `ggen sync` + reinstall (operator consent, host state) | r7 G1 |
| 20 | `config/dev.exs` program rows (`autofde-lab`, `gymact`, others) | paths under `~/xaas/worktrees/repos/` — ENOENT | **RESOLVED (receipt)** — paths re-pointed to canonical checkouts; `autofde-lab` → `~/autofde-lab`, `gymact` → `~/gymact` (disk-verified, `dev.exs:190-201`); gymact/autofde rows resolve (no ENOENT) | none for these rows (other worktree-row re-points out of closure scope) | r11 gap 1, r8 gap 1 |
| 21 | `~/gymact/.venv/bin/python` | venv absent | **RESOLVED (receipt)** — W9: venv bootstrapped via `uv sync`; `~/gymact/.venv/bin/python` present (disk-verified 2026-10-06) | none | r8 gap 2, w9 |
| 22 | `~/ferroplan/crates/ferroplan-wasm/registry/ferroplan_wasm.wasm` | untracked artifact (sha256 `088d9c3b…`, 3,521,589 B, pin-matched, wasmtime court 54 pass) | **PARTIAL (receipt)** — W45: artifact built + qualified (wasmtime court); commit still pending — `git status` shows untracked (disk-verified 2026-10-06) | coordinator `git add` + commit (WP-B) | w45 |
| 23 | `~/zcode-cli` 18-file dirty stream | max-turns/expert-strategy/typed-skip stream | **PARTIAL (receipt)** — zcode stream green w46/w58 (stream tests 19/19, full unit suite 1072 pass); commit pending — 18 files still dirty (disk-verified 2026-10-06) | one coherent commit to its branch (WP-C) | r7 G3, w46, w58 |
| 24 | `~/beam4pm` 2,462 dirty files | classification + split plan (C1…C7) filed | **RESOLVED (receipt)** — W52/W74 qualification gate run (OTP-29 compile/test adjudicated, receipt on disk `w52-beam4pm-qualification.md`); split commits remain OS-5 (operator-gated) | OS-5 operator decision for C1→C7 sequencing | r9, w52, w74 |
| 25 | `~/ash_surface` residual `_build-*` (5 dirs, ~1.40 GB) | `_build-fleet-ash_surface`, `_build-nsprefix`, `_build-pub`, `_build-tdb-surface`, `_build-w16-11` | **RESOLVED (receipt)** — lane lease `_build-*` dirs deleted at integration (cleanup-law executed; `ls ~/ash_surface/_build-*` → no matches, disk-verified 2026-10-06) | none | x2 §5, x7 R9, vector5 |
| 26 | `~/ash_surface/mix.exs:4` | `@version "26.10.1"` | **RESOLVED (receipt)** — W19 version bump landed via lawful script; `@version "26.10.6"` at `mix.exs:4` (disk-verified 2026-10-06) | none | x2, x4, w19 |
| 27 | `test/xaas/receipt/r_projection_test.exs:22` | silent `File.regular?` skip on validator absence | untested-skip | convert silent skip → presence `flunk` on CI | vector3 §2 |
| 28 | `~/zcode-cli` `prepare-release.yml` | 5 consecutive scheduled failures (Class 2: npm latest `3.14.4-32` vs main `3.14.3-1`) | ignored (workflow correct; tree behind npm) | version-bump release decision on main (operator-gated) | w40, x5 |
| 29 | `ggen_igniter` ash-manufacture-pack | fixture-only at `test/fixtures/ash_manufacture_pack/`; hex path UNSUPPORTED | **RESOLVED (receipt)** — pack promoted to `priv/ggen/ash-manufacture-pack/` (bin/gates/ontology.ttl/templates/verify present, w338 disk-verified); suite 1555/0 + credo clean at promotion | WP-G ship-scope decision remains OS-4 (operator) | r3, w338 |

---

## 2. Refusal & Verification Deficit

Baseline (vector2, batch 1–4 pre-state): **50 distinct `REFUSED_*` variants
declared in xaas `lib/` with zero test-tree tokens**, plus 4 actuation error
atoms, plus both fail-closed branches of `RequireInternalApiToken`, plus 25
castle-family variants + `BLOCKED_CASTLE_TRANSPORT`, plus 3 VKG variants.

Covered after batches 1–4 + W13/W18 (evidence: W51 tree manifest —
`test/xaas/castle_refusal_negative_test.exs` + `_batch2/_batch3/_batch4`,
`test/xaas/actuation_refusal_negative_test.exs`,
`test/xaas/semantics/vkg_refusal_negative_test.exs`,
`test/xaas_web/plugs/require_internal_api_token_test.exs`,
`test/xaas_web/endpoint_body_limit_test.exs` all present as new files;
`test/xaas_web/live/witness_live_test.exs` present):

| family | variants at baseline | negative fixtures now on disk | receipt |
|---|---|---|---|
| Castle engine (`REFUSED_CASTLE_*` etc., 25 + `BLOCKED_CASTLE_TRANSPORT`) | 26 | batches 1–4 — **ADJUDICATED (receipt)**: combined run 44/44 green (w67) | w67 |
| Actuation error atoms (`:external_admission_identity_mismatch`, `:external_input_mismatch`, `:external_projection_mismatch`, `:external_receipt_intent_mismatch`, `:subject_id_required`, `{:external_checkpoint_conflict,…}`, untyped rescue) | 7 | `actuation_refusal_negative_test.exs` — **ADJUDICATED (receipt)**: 5/5 green (w121) | w121 |
| VKG (`REFUSED_XAAS_VKG_WITNESS`, `REFUSED_XAAS_VKG_REPLAY`, `REFUSED_VKG_EMPTY_CATALOG`) | 3 | `vkg_refusal_negative_test.exs` — **ADJUDICATED (receipt)**: 3/3 green (w18) | w18 |
| Fail-closed plug (no-header/env-unset → 503; wrong token → 401; `assigns[:current_org]` nil) | 3 branches | `require_internal_api_token_test.exs` — **ADJUDICATED (receipt)**: 7/7 green (w13); endpoint body-limit 3/3 + 16/16 (w22) | w13, w22 |
| `REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED`, `REFUSED_XAAS_CHECKPOINT_WITNESS_MISMATCH`, `REFUSED_XAAS_CASTLE_CHECKPOINT_REQUIRED`, `REFUSED_XAAS_ADMISSION_EXPIRED`, `REFUSED_XAAS_ADMISSION_MISMATCH`, `REFUSED_XAAS_INTENT_NOT_EXECUTING`, `REFUSED_XAAS_CHECKPOINT_HASH_REQUIRED`, `REFUSED_INVALID_CASTLE_DIGEST`, `REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED` | 9 | covered inside castle batch files — ADJUDICATED via w67 **except** `REFUSED_XAAS_INTENT_NOT_EXECUTING` (token-level recount w176: no test/ assertion — closing in batch6/w185) | w67, w176 |

Caveat (updated 2026-10-06, W144 integration lane): the batch families above
are now **adjudicated-with-receipt** (w67 castle 44/44, w121 actuation 5/5,
w18 VKG 3/3, w13 plug 7/7, w22 endpoint). The w13/w18/w67/w121 receipt files
themselves are **not yet on disk** under `docs/sjira/v26.10.6/plans/` — the
adjudication counts above are lane-reported; the `comm -23` re-run
(vector2 falsifier) remains the authoritative remaining-variant count.

**Structurally-unreachable / intentionally-unfixed refusal shapes** (typed,
per vector2 §F — a deterministic-halt fixture is not possible until typed;
re-verified 2026-10-06 by w321-unreachable-reverify.md — 4 CONFIRMED /
6 STALE-line / 2 REFUTED corrections applied):

- ~~`castle.ex:941` `BLOCKED_CASTLE_TRANSPORT`~~ **REMOVED (w321 REFUTED)**: now a
  typed tuple at `castle.ex:950` (`{:error, {:BLOCKED_CASTLE_TRANSPORT, %{...}}}`)
  and already fixture'd (`castle_refusal_negative_batch4_test.exs:94-113`).
- `actuation.ex:382` (was :383) untyped rescue → `{:exception, struct, map}` (:388)
  (fixture pins shape only).
- Bare-string refusals (lines re-verified w321): `stop_court.ex:1956`,
  `eds/falsifier.ex:84`, `a2a/zoe_event_simulation_agent.ex:65,68`,
  `a2a/next_read_user_agent.ex:211,214`, `health_controller.ex:113,148`,
  `marketplace_catalog_live.ex:79-91` (substantially typed; residual
  `Exception.message` only) — typed-refactor-only, out of closure scope.
  ~~`capability_coverage.ex:59`~~ **REMOVED (w321 REFUTED)** — no refusal shape
  in that file; :59 is a report printer.
- ash_surface JS projector untyped string throws (`REFUSED_UNKNOWN_ACTION`,
  `REFUSED_NOT_DO_BOUNDARY`, `projectors/js.ex:494,501`) — machine-readability
  gap, not fixture-able.
- `vkg.ex:52` `REFUSED_VKG_EMPTY_CATALOG` dead clause — **STRUCTURALLY UNREACHABLE
  (w378 proof)**: `Registry.admit/1` refuses `[]` contracts outright, so
  `Catalog.ids/1` can never return `[]` through any public entry; the real
  empty edge refuses earlier as `REFUSED_VKG_MANIFEST` (fixture exists).
  Operator/next-cycle: delete the dead clause + redundant guard.
- Mix-task bare `"REFUSED"` stdout strings — **12 files / 21 sites** (w321 recount;
  was "13 tasks"): stop_court 4, successor 4, episode 3, fabric.redeploy,
  release_audit, autonomic.controls, sjira.engineer_work,
  safe_generate_migrations, release_snapshot.verify 2, self_digest, ash_surface,
  run_validate:83 (stdout renderer of a typed code, not a refusal shape).

ash_surface: **zero variant-level token gaps** (vector2 `comm -23` empty);
remaining quality traps: doctest-only standing coverage (C′), no 200/503 HTTP
mapping fixture (C″). Both stay open as typed, small test additions.

---

### 2.1 Authoritative delta recount (w176, 2026-10-06)

Token-level `comm -23` (lib 62 / test 49): **delta 50 → 16; coverage 46/62 = 74.2%**,
all 16 genuinely uncovered (zero covered-by-behavior, zero structurally unreachable):

- **13× castle outer-intent/receipt verification gate** (castle.ex:360-421, via
  `Xaas.Castle.witness/3` on a mutated RouteCastleRun intent/receipt): INTENT_NOT_EXECUTING,
  RESOURCE_MISMATCH, ACTION_MISMATCH, SUBJECT_MISMATCH, PROJECTION_MISMATCH, PROJECTION_DRIFT,
  IDEMPOTENCY_MISMATCH, RECEIPT_INTENT_MISMATCH, RECEIPT_NOT_PREPARED, RECEIPT_ACTION_MISMATCH,
  RECEIPT_PROJECTION_MISMATCH, RECEIPT_INPUT_MISMATCH, RECEIPT_REPLAY_TOKEN.
- **1×** `REFUSED_REQUIRED_FIELD` (castle.ex:501/506/1040, tuple
  `{:error, {:REFUSED_REQUIRED_FIELD, key}}`).
- **2× R2RML**: NON_UNIQUE_SEMANTIC_IDENTITY (r2rml.ex:185), UNKNOWN_ATTRIBUTE (r2rml.ex:212).

Closing in batch6/r2rml-refusal test files (lane w185, in flight). §2's w67 row was
corrected per w176 (INTENT_NOT_EXECUTING was claimed adjudicated; recount refuted it).

**CLOSED (w185 + w208, 2026-10-06):** all 16 tokens covered — batch6 (18 tests, 13 castle-gate
mutations + REQUIRED_FIELD admission/CLI paths) + r2rml_refusal_test (2 tests, one token
reclassified structurally unreachable with call-graph evidence: UNKNOWN_ATTRIBUTE's
`is_nil(attribute)` cannot hold through any public entry — projection is derived, never
injected). Authoritative recount (w202): **delta 0, coverage 62/62 = 100%**. Combined gate:
20/20 (w208). Consolidated capstone: w236.

## 3. Drift & Clean-Tree Reconciliation

From vector4 + W36/W37-class integration findings (w51 tree manifest):

**Commit-ready (regenerated, verified or verified-adjacent):**
- castle-bridge generated set (vector4 finding 1): run root `ggen sync run`,
  commit the injection into `lib/xaas/castle.ex` + 6 outputs
  (`lib/xaas/generated/castle_bridge_{contract,edges}.ex`,
  `test/xaas/generated/castle_bridge_contract_test.exs`,
  `priv/semantic/generated/castle_bridge_shacl.ttl`,
  `docs/claude/diataxis/reference/generated-castle-bridge-errc.md`) — CI
  `castle-paas-bridge.yml` already asserts them; the committed tree currently
  fails its own grep. Files already present untracked (w51).
- `priv/chicago/*.json` (4) and `priv/zcode_plugin/*` — verified byte-identical
  to fresh render (vector4 findings 3); nothing to do, keep as zero-diff exemplars.
- `~/ferroplan` wasm artifact + 4 ggen receipt artifacts — commit as chore (w45, r6 §0).
- `ggen.lock` at xaas root (new, untracked — w51) + ash_surface re-pin proposal
  (`baa5f117` → `93895f808`, r2 edit 2; xaas castle-bridge re-pin optional, r2 edit 3).

**Stays excluded / permanent:**
- `unless_exists` receipt templates (`.ash-gen-receipts/`, `.agp-receipts/`,
  `.terraform-validate-receipts/`) — first-run receipts, not parity surfaces (vector4).
- beam4pm `receipts/engine_ops/` new files (ignored), ERC/soak runtime artifacts (r9 G7/G7b, C6 decision pending).
- autofde-lab 2 vendor gitlink smudges — `git submodule update` is coordinator's, not a closure edit (r11 risk).
- `GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt` at xaas root — lane artifacts, delete at integration (w51).
- `erl_crash.dump` (x1b) — delete.

**LOCK_STALE / pin items (coordinator-only seams, x4 §4):**
- `mix.lock` rows for `ash_a2a` (3325032d → 07180bd3), `ash_pplan` (b9da1ad →
  414a393/v26.10.6), `ash_r2rml`, `ex4pm` — regenerate via `mix deps.update`;
  never hand-edit (x4 note).
- xaas `VERSION` `26.10.2` → milestone version (SEAM 3); ash_surface `@version
  "26.10.1"` → bump (SEAM 2); ash_pplan `26.10.3` → bump (SEAM 1);
  wasm4pm `26.9.28` (SEAM 4). ggen_igniter hex `~> 26.10.1` gated on hex
  publish (SEAM 5).
- zcode-cli version scheme excluded (`3.14.3-1`, independent; w40/`x4` §5).

**Remaining sync gates to wire (all currently absent — vector4):**
1. xaas root `ggen sync run` + `git diff --exit-code` as a PR gate (currently
   fails — castle.ex injection absent at HEAD).
2. ash_surface root-manifest sync + clean-tree lane (currently zero gate).
3. `mix xaas.ash_surface` + `git diff --exit-code priv/ash_surface` CI leg (x8 gap 3).
4. `MIX_ENV=prod mix compile --warnings-as-errors` CI leg (EA34 falsifier run
   once by hand — x8 gap 4; currently green per vector5).
5. No ggen-drift alias in `mix.exs` (vector4) — optional alias, gate first.

---

## 4. v26.10.6 Work Packages

Phased, closure-only. Every package carries: owning receipt, exact files,
verification command, and a no-new-features line.

### Phase 0 — unblock compile (hard prerequisite for everything)

| id | package | owning receipt | files | verify command | no-new-features |
|---|---|---|---|---|---|
| P0-1 | Fix/complete `gymact_surface.ex` syntax (TokenMissingError `:232`) | w51 | `lib/xaas/operations/gymact_surface.ex` | `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile` → exit 0 | repairs an in-flight lane file; adds no route or module beyond what the lane already staged |
| P0-2 | Resolve `AshA2A.Protocol.Agent` gap: bump ash_a2a pin `3325032d` → `07180bd3` (x4 SEAM 6) OR retarget the adapter to the pinned surface | r4, w30, w51, x4 | `mix.exs:103-105`, `mix.lock` (regen), `lib/xaas_web/a2a/next_read_ash_agent.ex` | `MIX_ENV=test mix compile && mix test test/xaas_web/` | pin alignment to an existing released surface; no new capability |
| P0-3 | Resolve `AshPPlan.Continuation` undefined in pplan bridge: retarget to pinned API or bump pin (SEAM 8, after ash_pplan v26.10.6 cut — WP-A) | w51, r5 | `lib/xaas/bridges/pplan.ex`, `mix.exs:251-253`, `mix.lock` | `MIX_ENV=test mix test test/xaas/chicago/bridges/pplan_test.exs test/xaas/ultracode/recovery_policy_test.exs test/xaas/frontier_evidence_test.exs` | restores compile of an existing bridge; regression courts are the boundary |

### Phase 1 — verification debt (tests only, no lib/ surface changes)

| id | package | owning receipt | files | verify command | no-new-features |
|---|---|---|---|---|---|
| P1-1 (RP-0) | Run + adjudicate refusal batches 1–4 and the plug/endpoint tests; re-run vector2 `comm -23` and record the true remaining count; file the W13/W18-equivalent receipt that is currently missing | vector2, w51 | `test/xaas/castle_refusal_negative{,_batch2,_batch3,_batch4}_test.exs`, `test/xaas/actuation_refusal_negative_test.exs`, `test/xaas/semantics/vkg_refusal_negative_test.exs`, `test/xaas_web/plugs/require_internal_api_token_test.exs`, `test/xaas_web/endpoint_body_limit_test.exs` | `MIX_ENV=test mix test test/xaas/castle_refusal_negative_test.exs test/xaas/castle_refusal_negative_batch2_test.exs test/xaas/castle_refusal_negative_batch3_test.exs test/xaas/castle_refusal_negative_batch4_test.exs test/xaas/actuation_refusal_negative_test.exs test/xaas/semantics/vkg_refusal_negative_test.exs test/xaas_web/plugs/require_internal_api_token_test.exs` | runs existing test files; produces a receipt, no code |
| P1-2 | Fill remaining refusal variants that batches 1–4 do not cover (delta from P1-1's `comm -23` re-run) | vector2 | new test files only, mirroring batch shape | same ladder as P1-1, plus delta file | negative fixtures only — assert existing refusals, change no lib/ |
| P1-3 | Un-skip `/chicago/seller` live test (route already registered) | vector1, vector3, x3 | `test/xaas/chicago/seller/seller_live_test.exs:308` | `MIX_ENV=test mix test test/xaas/chicago/seller/seller_live_test.exs` | deletes a skip marker; zero code |
| P1-4 | ash_surface standing-evidence adversarial fixture + health 200/503 mapping fixture (vector2 C′/C″) | vector2 | `/Users/sac/ash_surface/test/…` (2 small tests) | `mix test` in ash_surface | tests only |
| P1-5 | One-command un-ignores confirmed in vector3-closure: export `GGEN_IGNITER_DIR` in CI/test.full; convert r_projection silent `File.regular?` skip → presence `flunk` on CI; wire ard_court/ex4pm_staleness un-gated runs (clones present) | vector3, vector3-closure-receipt | `test/xaas/receipt/r_projection_test.exs:22`, CI env wiring | `GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/xaas/receipt/ test/xaas/ultracode/origin_authority_test.exs test/xaas/sjira/ard_court_test.exs` | environment gating only |
| P1-6 | Adjudicate semantic_drive_anchor 2 real failures (`REFUSED descriptor_refused not_eligible EP-A unknown_identity` from sibling ggen_igniter @ HEAD) — cross-repo subject mismatch, coordinator-level | vector3-closure-receipt | (diagnosis + fix in anchor test or sibling subject pin) | `GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/xaas/ultracode/semantic_drive_anchor_test.exs` | repairs an existing oracle; no new surface |
| P1-7 | autofde oracle gate CI wiring: install autofde-lab package on runner (recipe in w35); re-run yield_test quiet-checkout to resolve the 0-skips topology question | w35, vector3-closure-receipt | CI env, no test code | `MIX_ENV=test mix test test/xaas/sjira/yield_test.exs` → 8 passed, 0 failures | CI provisioning of an existing oracle |
| P1-8 | Boundary tests for the 3 untested caps (vector5): `keep_tail` at max/max+1, OCEL rotation over-limit, `admit_positive` refusal; explicit `:length` on Plug.Parsers | vector5 | `test/xaas/ultracode/…`, `test/xaas/telemetry/…`, `lib/xaas_web/endpoint.ex:71-77` | `MIX_ENV=test mix test test/xaas_web/endpoint_body_limit_test.exs` | one config option + boundary tests of existing caps |

### Phase 2 — drift & clean-tree

| id | package | owning receipt | files | verify command | no-new-features |
|---|---|---|---|---|---|
| P2-1 | Root `ggen sync run`; commit castle.ex injection + 6 outputs | vector4 | `lib/xaas/castle.ex`, `lib/xaas/generated/castle_bridge_*.ex`, `test/xaas/generated/*`, `priv/semantic/generated/castle_bridge_shacl.ttl`, docs ERCC page | `ggen sync run && git diff --exit-code` (post-commit) | projection of the existing canonical graph |
| P2-2 | Wire sync-drift PR gates: xaas root sync + diff; `mix xaas.ash_surface` + `git diff --exit-code priv/ash_surface`; prod-compile leg (EA34) | vector4, x8 | `.github/workflows/…` (new CI steps only) | run the lanes locally once: `ggen sync run; git status --short` → empty | CI gates; no application surface |
| P2-3 | ash_surface root-manifest sync: commit the 15 files or add the clean-tree lane (decide per repo doctrine) | vector4 | ash_surface generated set | `cd ~/ash_surface && ggen sync run && git diff --exit-code` | projection commit |
| P2-4 | Regenerate `priv/ash_surface/*` under current ash_surface (closes `generatorIdentity v26.10.1` skew) + persist `surface.digest` in contract JSON (x8 gap 5) | vector6, x8 | `priv/ash_surface/*`, `lib/mix/tasks/xaas.ash_surface.ex` | `mix xaas.ash_surface && git diff --exit-code priv/ash_surface` | regeneration of tracked projections |
| P2-5 | Registry re-hash / digest manifest for xaas machine registries (vector6 table: surface_contract, live_view, aria, runtime_surface, remote-relay) — adopt vector6's audited baselines or add a MANIFEST | vector6 | new `MANIFEST.json` or doc rows | `shasum -a 256` vs recorded rows | records digests; changes no artifact |
| P2-6 | Docs staleness sweep S1–S10 (vector6 §3): 19-domain counts, `/marketplace-catalog` route row, changelog backfill v26.9.30→current, README snapshot re-pin, Witness reference page | vector6 | `README.md`, `CHANGELOG.md`, `docs/claude/diataxis/reference/{ash-configuration,http-api-surface}.md`, ash_surface `CHANGELOG.md` | re-run vector6 falsifier greps | doc corrections to match shipped code |
| P2-7 | Integration cleanup: delete ash_surface `_build-*` (5 dirs ~1.40 GB), xaas lane artifacts (`GGEN-SH-*.log/txt`, `erl_crash.dump`), confirm no `_build-lane*` in final commit | x2 §5, x7 R9, w51, x1b | host dirs only | `ls ~/ash_surface/_build-*` → no matches | cleanup-law execution, no repo content |

### Phase 3 — Playwright closure (xaas browser surface)

| id | package | owning receipt | files | verify command | no-new-features |
|---|---|---|---|---|---|
| P3-1 | Full `npx playwright test` green run per x1b runbook (post P0): all 15 spec files, server booted with `INTERNAL_API_TOKEN`, marketplace catalog seeded | x1, x1b, w30 | `e2e/*` (run only) | `PATH=$HOME/.asdf/shims:$PATH npx playwright test` → green, real counts | execution of existing specs |
| P3-2 | Adjudicate the 9 new API/deep specs written by PW lanes (internal-api, execution-fabric, mcp-a2a, ggen-workbench, sparql-proxy, stripe-webhook, ash-admin-matrix, dev-routes, witness, a2a-v1, zcode-cli-fabric, chicago-pplan-deep, system-deep) against x1's court definitions; fix any red spec | x1 §4, r4 §5.8, w51 | `e2e/*.spec.cjs` | same ladder, per-file | specs assert existing surfaces incl. typed refusals; no new routes |
| P3-3 | `npx playwright test --list` sanity (must not be `0 tests in 0 files`; ESM/CJS renames already landed) | x1b | (none) | `npx playwright test --list` | none |

### Phase 4 — per-repo closure (outside xaas tree; coordinator/exec lanes)

| id | package | owning receipt | files | verify command | no-new-features |
|---|---|---|---|---|---|
| WP-A | ash_pplan: adjudicate the net-new 8th failure in `docs/demonstration.md`, land green, bump version, CHANGELOG, tag v26.10.6; then xaas pin move (feeds P0-3) | r5 | `~/ash_pplan/mix.exs`, `docs/demonstration.md`; xaas `mix.exs:251-253` | `mix test` in ash_pplan (2309 tests, back to 7 failures or all green); regression courts of P0-3 | release cut of existing surface |
| WP-B | ferroplan: commit wasm artifact + 4 ggen receipt chore (P0-free); then R6 hops stay OUT of v26.10.6 closure unless coordinator admits (bridge vendoring = new surface) | w45, r6 | `~/ferroplan/crates/ferroplan-wasm/registry/ferroplan_wasm.wasm`, `.ggen-v2/*` | `cargo test -p ferroplan-wasm --test pin_drift` → 7 pass | commits an existing verified artifact; no new bridge |
| WP-C | zcode-cli: commit the 18-file stream as one commit; unit suite is green (w58: 1072 pass / 0 fail); sha re-verify both contracts | r7, w46, w58 | 18 dirty files in `~/zcode-cli` | `ZCODE_REQUIRE_TOOLCHAINS=1 bun test test/*.test.ts`; `shasum -a 256` both contracts | commits an already-tested existing stream |
| WP-D | ggen E1: version bump + changelog `[26.10.6]` section (tag = E2, operator-gated below) | r1 | `~/ggen/Cargo.toml`, `docs/CHANGELOG.md` | `git grep 26.10.5 Cargo.toml` → 0; `cargo metadata` coherent | version metadata only |
| WP-E | ggen-marketplace: bump `[active].version` `26.9.12` → `26.10.6` (version-only; do not touch `[ggen]` pin, do not expand packs); regenerate standing.md | r2 | `marketplace.active.toml`, `docs/context/standing.md` | `python3 scripts/marketplace.py validate && python3 scripts/marketplace.py catalog` | label-only bump; pack set unchanged |
| WP-F | beam4pm: OTP-29 qualification gate (`mix compile --force` + `mix test` under 1.20.4-otp-29) — then r9 split-commit plan C1→C5b; unresolved compile = typed BLOCKED, no split lands | r9 | `~/beam4pm` per r9 §commit groups | r9 verification ladder steps 1–8 | lands already-generated projections of C1's graph |
| WP-G | ggen_igniter pack promotion E1–E5 (fixture → `priv/ggen/ash-manufacture-pack`, shipping denylist, `@source_pack` fix, doc sync) — coordinate with operator decision OS-3 | r3 | `~/ggen_igniter` per r3 §3 (2 commits) | r3 §6 falsifier | relocates an existing pack; consumer capability unchanged |
| WP-H | autofde-lab + gymact dev.exs path re-points (dead `~/xaas/worktrees/repos/` prefix → canonical checkouts); gymact venv mint; gymact `fastapi.py:37` version string fix | r11, r8, w35 | `config/dev.exs` (xaas), `~/gymact/src/gymact/surfaces/fastapi.py` | program registry resolves (no ENOENT); `mix test test/xaas_web/live/autofde_lab/status_live_test.exs`; `e2e/autofde-lab.spec.cjs` green | corrects dead paths to existing checkouts |
| WP-I | wasm4pm: file the missing r10 receipt (audit: CI/fmt/tsc + typed NOT_REQUIRED wiring verdict) — standing cannot leave UNKNOWN without it | _FRONTIER wasm4pm row | `docs/sjira/v26.10.6/plans/r10-*.md` | repo's own `ci.yml` on release head | receipt only |
| WP-J | gymact E1: `pyproject.toml` version → current; commit 3 dirty doc files as landing receipt commit | r8 | `~/gymact/pyproject.toml`, 3 doc files | gymact pytest courts | version metadata + docs |

### Operator-decision register (explicitly operator-gated — NOT lane work)

| id | decision | owning receipt | unblocks |
|---|---|---|---|
| OS-1 | **AshA2A strict preflight** — decide auth stacking for `/a2a/v1` mount (token gate vs `AshA2A.Protocol.Plug.Auth` identity pass-through; r4 risk: double-401 or bypass) before the mount edit is admitted | r4 §7 | r4 edits 3–4, `e2e/a2a-v1.spec.cjs` final form |
| OS-2 | **zcode main version bump** — advance `~/zcode-cli` `package.json` past npm latest `3.14.4-32` (`3.14.4-33` or `3.14.5-1`) on main; the prepare-release guard is correct and must not be patched | w40 | clears 5-consecutive-failure release workflow |
| OS-3 | **ggen tag E2** — cut tag `v26.10.6` after CI green on WP-D bump commit | r1 E2 | unblocks R2's pre-staged frozen-court ggen pin bump (`BLOCKED:release-artifacts`) |
| OS-4 | **ship-scope E3** — ggen_igniter hex package ship scope for the promoted ash-manufacture-pack (whole pack vs ontology/gates/templates/verify only) | r3 E3/R-5 | WP-G final layout |
| OS-5 | **beam4pm split** — approve/sequence the r9 C1→C7 commit groups (and the C6 `receipts/engine_ops` untrack decision) after WP-F qualification | r9 | resolves the 2,462-file dirty subject into receiptable commits |
| OS-6 | **ggen-marketplace frozen ggen pin** `v26.8.11` @ `402cecdf` — remains `BLOCKED:pin-bump-user-gated`; only the user lifts it | r2 §4.4 | qualification-identity skew resolution |
| OS-7 | **ash_surface G1b** — convert xaas path dep to versioned (hex/git) dep | x2 G1b, x4 | replay identity beyond a lease-shaped path dep |
| OS-8 | **zcode plugin cache reinstall** — mutates host state `~/.zcode/cli/plugins/cache/…`; explicit operator consent required | r7 R6/step 5 | clears plugin 26.9.17 skew |
| OS-9 | **BLOCKED(law_evolution) — GC23 court redesign**: xaas courts GC23-0/2/3/12 (`docs/sjira/v26.9.23/courts/*.sh`) require compile_prose's retired output surface (orders.ttl + ADMITTED/REQUIRED_BY lines); ggen_igniter dc27242 retired it by design (SJ-002: Prose ↛ WorkOrder; observe_prose emits propositions.ttl only). 4 court tests fail at 52/56. Fix = redesign courts to observation-only law — v26.10.7+ work, NOT convergence | w133b STOP report + w107/w128 | GC23 court tests 56/56 under the observation-only law |
| OS-10 | **BLOCKED(new-code) — gymact DCM-018 standing-feedback**: the DCM chain executes end-to-end with a real witnessed, replayable closure-bound receipt (adae920d…, w129), but witnessed_crown can't flip without a standing-feedback overlay writer + crown-premark-law change — new capability, out of v26.10.6 scope. The witnessed execution itself is the milestone fact. *(Sync W190: absorbs former OS-12 candidate — w129 confirmed the flag is unreachable by construction, same item; no separate row.)* | w129 receipt adae920d | witnessed_crown flip via standing-feedback overlay + crown-premark-law change (v26.10.7+) |
| OS-12 | **W183 Token revocation disclosures (convergence-honest, NOT DoD failures)** — (a) `:revoke_token` is BLOCKED in MIX_ENV=test: `EnforceSingleRevoke` → `RevokeNonce.claim` fails on first call with AshOnetime `:store_invariant` ("authoritative admission store failed", `deps/ash_onetime/admission.ex`) — probed sandboxed and unsandboxed; revocation lifecycle is covered via `:revoke_jti` (same `:is_revoked` check). Needs an ash_onetime admission-store fixture/decision — operator/ash_onetime-owner item, NOT xaas closure. (b) jti PK collision under `store_all_tokens?(true)`: the revocation row reuses the token row's jti PK (test works around in-sandbox); the resource's real schema may want a distinct revocation-row identity — design question, operator. Evidence: `test/xaas/accounts/token_revocation_test.exs` | W183 findings | ash_onetime admission-store fixture (a); revocation-row identity design decision (b) |
| OS-13 | **Recurring sync-installer emission into ash_surface lib/**: the ash-extension-pack's root sync re-emits consumer-installer products (`lib/ash_r2rml/`, `lib/ash_a2a/`, `lib/audit_trail/`, `lib/notification_extension/`, `lib/mix/tasks/*_install.ex`) into `~/ash_surface/lib` on every sync run; they shadow real hex deps — W224's "API skew" was actually the ash_r2rml stub shadowing (corrected at w230) — and break compilation until quarantined. W126 added the `aex:fixtureOnly` marker for AshA2aSpec; the r2rml/audit_trail/notification_extension families need the same marker at the pack ontology level (ggen-marketplace-side fix), OR the sync needs a consumer-mode flag that suppresses installer emission for self-host runs. Convergence-honest: the workaround (quarantine after each sync) is recorded in w230-r2rml-skew.md; the durable fix is pack-side — next cycle or operator-directed now. Evidence: w230-r2rml-skew.md (quarantine + restore instructions), w37 doctrine (excluded outputs), w126-pack-gate-fix.md (fixtureOnly precedent) | w230-r2rml-skew.md, w126-pack-gate-fix.md | `aex:fixtureOnly` marker extended to r2rml/audit_trail/notification_extension at pack ontology level, or a consumer-mode sync flag suppressing installer emission for self-host runs |
| OS-11 | **UNOWNED/UNKNOWN — fleet-wide permission-bit stripping**: `drw-------` observed on `priv/deps` subtrees across 4+ repos, found independently by w91/w75/w151/w20; repaired in place per repo, root cause not identified. Operator action: identify what ran `chmod` under a restrictive umask (suspect: a fan-out lane or cleanup step executing with a non-default umask) so it can be guarded. *(Sync w365: fleet re-probe 2026-10-06 → 0 owner-unreadable dirs in 9 repos — no recurrence; watch item only.)* | w91, w75, w151, w20, w365 | prevents recurrence of unreadable priv/deps subtrees on future lanes |
| OS-14 | **EU-AI-Act Art. 12(3) authority-export surface** — **LANDED 2026-10-06 (W620)**: runtime export API exists — `GET /internal-api/eu-ai-act/pack` (token-gated, fail-closed, shares W513 CLI build core; 15/0 tests incl. determinism + typed 401). Combined with the doc-level ledger (w600/W336 JCS export) the map gap narrows further to retention/persistence only. | w620-os14-export-endpoint.md, w513 | Art. 12(3) runtime-API leg EVIDENCED |
| OS-15 | **EU-AI-Act Art. 14(4)(e) bias-awareness doc-class** — **CLOSED (doc-class) 2026-10-06**: `docs/cro/artifacts/bias-awareness-measures-v26.10.6.md` authored, evidence-grounded, with 5 typed limitations carried (incl. LIMITATION(NO_DEMOGRAPHIC_BIAS_DETECTION) — no fairness code exists; replayable ≠ fair). Coverage-map GAP row narrows to the code-level limitation | w423 | Art. 14(4)(e) EVIDENCED-with-limitations |
| OS-16 | **EU-AI-Act Art. 50 end-user disclosure** — typed GAP: no end-user-facing AI-interaction disclosure surface. NEW FEATURE — v26.10.7+ | w319 | Art. 50 EVIDENCED flip |
| OS-17 | **CLOAK_KEY prod guard** — **FIXED 2026-10-06**: `Xaas.Vault.init/1` prod branch returns `{:stop, {:cloak_key_missing, :prod_refuses_placeholder_key}}` (fail-closed; dev/test unchanged); guard tests 4/4 incl. source pin (w349 receipt + w393 wiring trace; CHANGELOG entry landed). | w349, w393 | row 5 RESOLVED flip |
| OS-18 | **actuation checkpoint_external identity clause — FIXED 2026-10-06 (W546)**: the tautological dead clause was replaced by a LIVE comparison (admission-carried resource/action/subject_id/carried_input_hash vs intent + receipt carried hashes); a forged internally-consistent foreign {intent, receipt} pair is now refused `:external_admission_identity_mismatch`. Witness flipped to assert refusal + positive control added; mutant KILLED (clause→false→ witness fails, revert→7/7); corpus 80/80 contention-adjusted (13 castle-lock CONTENTION per w398b signature, 0 assertion failures). Same-context indistinguishability disclosed per w379. v26.10.6 safety-law change LANDED. | w379, w546-os18-fix.md | DONE — corpus kill + witness flip + mutant killed |
| OS-19 | **release_audit stale v26.8.21 pin** — w467: `lib/mix/tasks/xaas.release_audit.ex:14` `@version "26.8.21"` makes the audit refuse at HEAD (fail-closed, MEDIUM — unusable baseline, not false-green). Fix: one-liner `@version File.read!("VERSION") |> String.trim()` (mirrors mix.exs:13, never stale) + a `run/1` regression test; census checks then correctly refuse on drift. v26.10.7 candidate or coordinator one-liner | w467 | audit usable at 26.10.6 |
| OS-21 | **EU-AI-Act gate non-totality escapes (CRITICAL, w621 fuzz)** — 4 adversarial-input classes raise instead of mapping to ⊥: (1) RobustMargin.admit/4 FunctionClauseError on guard-domain mismatch, (2) DatasetAdmission.admit/2 Protocol.UndefinedError on non-enumerable :features, (3) EuAiActAdmission.admit/1 FunctionClauseError on improper-list values, (4) BEAM badarith on float overflow in arithmetic positions of all three gates. The dissertation totality claim (α_B: V→{⊤,⊥}, never raise) is violated. Fix: typed catch-alls/guards per gate; the w621 fuzz suite flips from documenting escapes to asserting typed handling. | w621-admission-fuzz.md | fuzz suite asserts totality; KillScore includes the 4 escape mutants | W600 landing note: fix witnessed (version check passes, full 70-resource census traversed); audit now refuses at its LAST check on genuine pre-existing drift (`lib/kanban_web/router.ex` absent — kanban_web is not part of this tree). Two follow-ups: (a) that drift needs typing (stale audit reference or genuinely missing module — operator), (b) `check_rpc_alignment` crashes via `File.read!` instead of a typed refusal — fail-crash, not fail-closed (v26.10.7 one-liner).
| OS-20 | **OTP-29 `Map.update/4` absent-key deviation — 60 reliant sites, toolchain upgrade blocker** — w525d probe: on 1.20.4-otp-29 (beam4pm/ash_a2a/ash_pplan/ex4pm pins), `Map.update(%{}, :k, 7, fun)` stores default WITHOUT applying fun (documented semantics: fun applied). Census: 60/76 sites are accumulators relying on the buggy behavior (current runs correct; a runtime fix would double/duplicate all 60 at once). Fix: patch sites to the dual-safe `case Map.fetch` idiom BEFORE any toolchain upgrade. Ex4pm `inductive_miner.ex:327`/`process_ir.ex:757` (`0, &(&1-1)`) suspect under both behaviors. | w525d, w511 | upgrade-safe accumulator call sites | W705 extension (xaas itself): **12 absent-key-reliant `Map.update/4` sites in xaas's own lib/** (circuit:4, ocel_summary:2, turtle:3, workspace:1, sequenced_drain:1, run_validation:2, semantic_drive:1, process-plane:1 — w705 census). Xaas runs otp-28 (documented semantics — correct today), but the same toolchain-upgrade hazard applies. Fix lane: dual-safe rewrite + census/pin tests (w705's test file stubs landed).
**Progress (2026-10-06, W602+W604)**: 49/60 sites patched dual-safe (ash_a2a 14/14, suite 3720 green; ex4pm 35/35, suite 896 green incl. the two suspect-site behavior pins). Remaining: beam4pm 3 (W601 in flight), ash_pplan 8 (W603 in flight), + ex4pm `reference_oracle.ex:109` (`1, &(&1+1)`) found post-census — classify+patch follow-up (W609). Coordinator commits all four repos. W601 note **W620 consolidation (2026-10-06)**: 61/61 sites patched = 100% site-level (beam4pm 3/3 w601, ash_a2a 14/14 w602 suite 3720 green, ex4pm 36/36 w604+w609 suite 896 green, ash_pplan 8/8 on disk w603 — its receipt §6 suite-result line still pending W603's crawl-completion). Receipt-level 4/5. Remainders: W603 verdict fill + coordinator commits ×4 repos (w620-os20-consolidation.md). (beam4pm leg done, 3/3, touched modules 39/0): the new dual-safe test file needs coordinator admission under `bpm:HandAuthoredSource` (ontology.ttl + manifest regen) to clear the AuthorshipGate findings — the other 2 suite failures are pre-existing (evidence-chain SHA drift, w511 unadmitted module). **W657 refresh (2026-10-06)**: recount over `lib/**/*.ex` confirms 61/61 dual-safe sites on disk (beam4pm 3/2 files, ash_a2a 14/9, ex4pm 36/15, ash_pplan 8/7) — census exact, no drift since W620. All 5 regression test files PRESENT (beam4pm w601 2305B, ash_a2a 5524B, ex4pm w604 3652B + w609 1714B, ash_pplan 3452B). W603 receipt EXISTS (`plans/w603-ash-pplan-map-update.md`, 8/8 sites + compile exit 0/152 files) but its §6 result line is STILL `(filled at run completion)`; the follow-up suite-capture attempt W610 is `GATED(load)` (12-check window, min load 35.84 vs ≤10 threshold — no suite run). So per-repo suite verdicts: beam4pm 39/0 narrow + full 1562/1565 (3 pre-existing/gate-adjacent, plus AuthorshipGate admission item), ash_a2a 3720/0 exit 0, ex4pm 896/0 exit 0 + W609 gates 2/9/30, ash_pplan NO receipt-grade suite (narrow GREEN per W291; full capture twice gated/blocked). OS-20 standing: **100% sites (61/61) patched; 4/5 legs with witnessed suites; closure ≈ 80%** — remaining: (1) ash_pplan full-suite verdict (W603 §6 fill or a quiet-machine W610 rerun), (2) coordinator commits ×4 repos (all four working trees verified still uncommitted at refresh), (3) beam4pm `bpm:HandAuthoredSource` admission for the w601 test file. Receipt: `plans/w657-os20-refresh.md`.

### Resolved since W138 (register sync, W190 integration lane)

- **Receipt-schema drift (goal/stop courts, ex-29F)** — **RESOLVED by w107**: version-discriminating validator landed; 19/19 corpus ADMITTED; courts 52/56 with the residual fully attributable to OS-9 (GC23 law_evolution), not schema drift. Evidence: w107, OS-9.
- **AuthZEN cache fail-open (W77 defect 2)** — **RESOLVED by w130**: monotonic-time TTL landed; fail-open window closed; courts 11/11 × 5 runs. Evidence: w130.
- **CommandBus "defect"** — **REFUTED by w127**: tracing showed an environmental outbox-dir collision, not a product defect; test_helper sweep + naming landed by coordinator; 9/9 green plus isolation via `:timeout` tag. Evidence: w127.


- **OS-17 CLOAK_KEY prod guard** — **RESOLVED by w349+w393** (2026-10-06): prod
  branch fail-closed on placeholder key; guard tests 4/4; §1 row 5 flips to
  RESOLVED. Evidence: w349, w393.
- **OS-15 Art. 14(4)(e) doc-class** — **CLOSED by w423** (2026-10-06): bias-awareness
  measures doc authored with 5 typed limitations; coverage-map GAP row narrows to
  the code-level limitation. Evidence: w423.
Both OS-9 and OS-10 are convergence-honest BLOCKED entries: typed, evidence-linked, and explicitly not DoD failures — they gate future-cycle work, not v26.10.6 closure. OS-11 is an open operator investigation, not lane work.

## W230 link check (integration lane, 2026-10-06)

> **SUPERSEDED by w466 (2026-10-06):** all four originally-flagged dead links
> (w20, w128, w133b, w183) have landed on disk and now resolve. Row order is now
> OS-1…OS-10, OS-12, OS-13, OS-11, OS-14–OS-18. Remaining dead pointer found then
> (OS-13 "w37 doctrine") removed per F5.

Evidence-link audit of the OS-1…OS-12 register above, per §4 verification:

- **Numbering**: collision-free. Single OS-12 row (W199 token-revocation disclosures);
  OS-10 carries the W190 fold-in note ("absorbs former OS-12 candidate — no separate
  row"). No duplicate OS-12 rows. Row order is OS-1…OS-10, OS-12, OS-11 (OS-12
  appears before OS-11) — cosmetic ordering only, no collision.
- **Receipt links verified on disk** (`docs/sjira/v26.10.6/plans/`): r1-ggen.md,
  r2-marketplace.md, r3-igniter.md, r4-a2a.md, r7-zcode-cli.md, r9-beam4pm.md,
  x2-ash-surface.md, x4-version-alignment.md, w40-zcode-release-workflow.md,
  w91-permission-sweep.md, w75-ex4pm-baseline.md, w151-dev-migrate.md,
  w129-gymact-crown.md, w107-schema-drift.md — all `test -f` OK.
- **Non-file evidence verified**: OS-9's court path `docs/sjira/v26.9.23/courts/`
  exists (GC23-0.sh … present); OS-12's evidence file
  `test/xaas/accounts/token_revocation_test.exs` exists.
- **Dead links (flagged, no obvious re-point target)**:
  - OS-9 cites **w133b STOP report** and **w128** — no `w133*` or `w128*` receipt
    exists under plans/ and no other receipt names them; flagged, unresolved.
  - OS-11 cites **w20** among w91/w75/w151/w20 — w91/w75/w151 receipts exist;
    no `w20*` receipt exists; flagged, unresolved.
  - OS-12's owning receipt "**W183 findings**" — no `w183*` receipt file exists
    under plans/; the in-repo evidence test file does exist; the receipt pointer
    itself is dead; flagged, unresolved.

---

## 5. Definition of Done

v26.10.6 closes when ALL of the following hold, each with real executed output
in a receipt (never inspection):

1. **All tests green incl. un-ignored bounded suites.**
   `MIX_ENV=test mix test` green under the pinned asdf toolchain
   (`PATH=$HOME/.asdf/shims:$PATH`); the one-command un-ignored suites run
   un-skipped per vector3-closure (receipt dir 27/27 incl. r_projection,
   consistency 18/18, origin_authority 10/10, yield 8/8, successor 8/8,
   causal_receipt/process_receipt 16/16 — w329 recount; the earlier
   "lineage 24/24" figure had no on-disk referent, corrected per w329) with
   zero skips in the completed files; P1-6 semantic_drive_anchor adjudicated (8/8
   or typed). Opt-in classes stay opt-in per vector3 verdicts: `:kind`,
   `:requires_cnv_deploy`, `:stress`, `:castle_kernel`, `:external_llm` remain
   `test.full`-gated, not default-gated.
2. **Zero compiler/lint warnings under strict flags.**
   `MIX_ENV=test mix compile --warnings-as-errors` exit 0 in xaas and
   ash_surface (dep-only warnings, per vector5 baseline — preserved, not
   regressed); plus the EA34 prod leg `MIX_ENV=prod mix compile
   --warnings-as-errors` exit 0 wired into CI (P2-2), not hand-run only.
3. **Refusal coverage state witnessed.** P1-1 re-runs vector2's `comm -23`
   and files the delta count; every remaining reachable variant has a
   negative fixture or is on the structurally-unreachable list (§2) with a
   typed reason. The fail-closed `RequireInternalApiToken` floor has direct
   503/401/nil-assigns fixtures.
4. **Clean tree after generation.** `ggen sync run` at the xaas root manifest
   + `git diff --exit-code` → empty (castle.ex injection committed, 7 castle
   outputs tracked); `mix xaas.ash_surface` → `priv/ash_surface` byte-stable;
   ash_surface root sync clean-tree lane green; final integration commit
   contains no `_build-lane*`, no `GGEN-SH-*.log/txt`, no `erl_crash.dump`.
5. **Verify ladder per repo class** (x7 scope correction):
   - *Browser-surface repos* (xaas served surfaces incl. ash_surface-generated
     `/ash_surface` client): compile → test → wiring → full green
     `npx playwright test` (P3-1), all 15 spec files collected (P3-3 must not
     report 0 tests), run against a server with `INTERNAL_API_TOKEN` and the
     seeded marketplace catalog.
   - *CLI/library/planner repos* (ggen, ggen_igniter, zcode-cli, wasm4pm,
     beam4pm, ferroplan, gymact, ash_pplan, ggen-marketplace): compile → test
     → wiring check → typed receipt stating why rung 4 does not apply
     (`_FRONTIER.md` scope correction).
6. **Frontier all rows non-UNKNOWN.** Every `_FRONTIER.md` row carries
   standing ≠ UNKNOWN backed by a receipt path — this requires WP-I (r10 for
   wasm4pm), r8's falsifier run or a typed BLOCKED for gymact, and WP-F's
   qualification outcome for beam4pm. BLOCKED rows keep falsifier + blocking
   reason inline; unsatisfied operator decisions (OS-1…OS-8) keep their rows
   typed-gated, never silently UNKNOWN.
7. **No new features.** Every landed diff traces to an inventory row in §1, a
   deficit in §2, or a drift row in §3; any diff outside that set is out of
   scope for v26.10.6 closure and must be refused at review.

## Standing

PARTIAL_ALIVE — §1 inventory refreshed 2026-10-06 by W144 integration lane:
16 rows marked RESOLVED/PARTIAL with closing receipts (13 RESOLVED, 3 PARTIAL:
#18 W118 pending, #22 commit pending, #23 commit pending); §2 deficit table
adjudicated-with-receipt. Receipt citations follow operator lane testimony
(w9/w13/w18/w19/w22/w36/w37/w41/w42/w45/w46/w52/w58/w67/w70/w73/w74/w118/w121);
disk-verified rows say so inline. The sole write in this lane is this file.

## §5 DoD Status (W206)

> **SUPERSEDED by w422-dod-rewalk-v4.md (2026-10-06)** — its "§5 Status Table
> Replacement (coordinator paste)" is authoritative; ranges citing "OS-1…OS-8"/
> "OS-1…OS-12" are stale (register now OS-1…OS-19). Original walk preserved in
> `plans/w422-dod-rewalk-v4.md`.
>
> The w422 table was applied by W468 and is itself superseded by the W548
> final-landed-state table below (2026-10-06).

Integration lane W548, 2026-10-06. §5 replaced with the final landed state
(supersedes the W468-applied w422 table). Every verdict cites `test -f`-verified
receipts on disk under `docs/sjira/v26.10.6/plans/`.

| DoD | verdict | closing lane / condition |
|---|---|---|
| 1 tests green | **LANDED** — definitive full suite: lane W316b `plans/w316-tokened-full-suite.md` @ d1db2b03: 3231/3247 passed (36 skipped, 91 excluded), 0 real failures — all deltas contention-classified, castle-lock contention disclosed; slice witnesses `plans/w425-ultracode-slice.md` through `plans/w463-remaining-dirs-slice.md` on disk; mock gate [] witnessed (`plans/w340-banned-pattern-sweep.md`, w316b). Quiescent single-run confirmation: `plans/w473b-quiescent-suite.md` VERDICT **GATED(load)** — load gate (≥10 1-min) never admitted in 6 checks (~19 min), run not executed, nothing to clean (no build root minted). Honest note: the quiet single-run receipt is still pending and does not block the substantive verdict (contention-adjusted 0 real, witnessed twice: w316b runs 1+2) | none — pending item is the quiescent re-run, coordinator-scheduled |
| 2 strict flags | **LANDED (local legs) + CI advisory** — strict-compile legs `plans/w335-strict-compile-fresh.md` (incl. coordinator addendum: ash_surface REGRESSED → OS-13 quarantine → w371 QUARANTINE-CLEAN 36/0, re-verified EXIT=0) held post-OS-17 per `plans/w446-vault-strict-recheck.md` (strict recheck); format leg `plans/w395-format-rewitness.md` full-tree `mix format --check-formatted` exit 0 GATE-CLEAN. CI leg `plans/w327-ci-gates-draft.md` `closure-gates.yml` advisory-only (`continue-on-error: true`) — promotion is an operator action, not lane work | operator removes `continue-on-error` per job once green on main (w327); not a lane blocker |
| 3 refusal coverage | **LANDED** — refusal corpus at final tree `plans/w398-refusal-capstone-final.md`: 85-test corpus, 72/85 raw, **contention-adjusted 85/85, zero real failures, corpus ALIVE at final tree**; empty-bearer mutant KILLED `plans/w414-empty-bearer-kill.md` (503-vs-401 fail-closed cell); coverage 62/62 refusal tokens witnessed (`plans/w185-refusal-batch6-receipt.md`, `_CLOSURE_RECEIPT.md` line 379). **OS-18 FIXED**: W546 `plans/w546-os18-fix.md` replaced the `checkpoint_external/2` tautology with a LIVE clause — forged foreign admission pairs now refused `:external_admission_identity_mismatch`, witness flipped, mutant-killed, falsifier replayed (contention-free castle rerun 19/19 still open, disclosed). Consolidation flips W547 `plans/w547-gap-flips.md` (OPEN_GAP → EVIDENCED where module+test exist on disk: 50.2, 15.3, 15.5.s3, 14.4.b, 26.6/26.7/27.1-family). Deepening (grep-only → real typed behavior calls, Chicago): W616 `plans/w616-deepening.md` 22 bodies (Titles I–II incl. real `EuAiActAdmissionPlug.call/2` HTTP 200 envelope pin), W623 `plans/w623-title-iii-deepening.md` 54 lines (27 reclass + 27 evidence_map), W626c `plans/w626c-deepening-iv-xiii.md` 14 lines (Titles IV–V ×5, VI–XIII ×9, incl. 99.3 total-function fuzz repair). Art 73 flips: W607 `plans/w607-349-41-closures.md` 3.49-family ×5 → EVIDENCED; W625c `plans/w625c-art73-flips.md` Art 73 family ×9 (8 EVIDENCED, 73.9 NOT_APPLICABLE typed; open-gap census 24→15). Counterfactual harness: W550 `plans/w550-counterfactual-harness.md` (Pearl 3-step factual→do→typed-refusal, determinism ×2) + W624 `plans/w624-counterfactual-extension.md` + W624b repair `plans/w624b-harness-repair.md` **23/23 green ×2** (remaining W630 `proper_list?/1` lib defect fixed by its owner 23:12:14; title_ii full file 40/40). Honest: W551 kill ledger `plans/w551-counterfactual-kill-ledger.md` verdicts still PENDING in-receipt — cited as in-flight, not evidence | W551 mutant verdicts landing; contention-free castle rerun (folds into w398b residual) |
| 4 clean tree | **PENDING (coordinator)** — staging complete: w390 staged the 8-file sync-output into `plans/w390-sync-output-staging/` (sha256 manifest); `plans/w464-commit-manifest-v3.md` on disk. **Commits remain operator/coordinator-gated** — staging cannot self-commit | coordinator commit lanes per w390/w464 staging maps |
| 5 verify ladder | **Browser LANDED; CLI LANDED; ash_pplan LANDED** — browser: `plans/w471-pw-remint.md` quiescent run **96 passed / 0 failed / 2 typed stripe skips** (exact w438/w449/w460 lineage target), `plans/w317-pw-final-tokened.md` 96/0 (96+2 skipped = 98 = --list), admin settle `plans/w460-admin-spec-settle.md`; CLI rungs: `plans/w332-sibling-gate-reconfirm.md` ex4pm 888/0 GREEN @ 9f7aecda, `plans/w343-igniter-freshness.md` ggen_igniter ALIVE 1555/0 @ 7dbcdb3a, `plans/w364-beam4pm-freshness.md` beam4pm FRESH @ OTP-29 fresh build root, `plans/w635-ash-pplan-airo.md` also on disk. **ash_pplan W291 now ON DISK** `plans/w291-ash-pplan-verdict.md` @ ash_pplan 414a393 (fix/ggen-verify-header): patches landed both files verified on disk; **narrow gate GREEN (decisive)** `test/manufacture_test.exs`; full suite run 1 exit 0 but tail contaminated/truncated (cap-induced) — no full-suite verdict claimed; **P0-3 pins warning noted → commit-gate** | ash_pplan full-suite clean rerun + P0-3 pins resolution fold into coordinator commit gates |
| 6 frontier non-UNKNOWN | **LANDED** — DoD-6 audit `plans/w324-frontier-audit.md`: **(a) rows still UNKNOWN = 0**, no standing contradicts its receipts' verdict lines (dead-path/stale-citation fixes given as paste-in text); gymact `plans/w325-gymact-e2e-falsifier.md` ALIVE falsifier line (DCM-018 classified in-repo). wasm4pm standing remains CI-gated until the coordinator-gated commits land (DoD 4) — noted, does not flip any row to UNKNOWN. (w345/w415 cited upstream have no receipt on disk; w324 is the on-disk frontier-audit evidence.) | wasm4pm CI confirm post-commit (folds into DoD 4) |
| 7 no new features | **MET** — `plans/w323-dod7-provenance.md`: UNTRACED 0 (9 literal-match misses reclassified, hard-untraced 0); manifest v3 `plans/w464-commit-manifest-v3.md`; register check `plans/w466-os-register-check.md`. Provenance surface has since grown two whole waves landed after manifest v3: the **AIRo wave** (`plans/w600-airo-vendor.md` … `plans/w639-airo-ledger.md` — new `lib/xaas/semantics/airo_risk_mapping.ex` surface + per-repo maps) and the **counterfactual wave** (`plans/w550-counterfactual-harness.md`, `plans/w624-counterfactual-extension.md`, `plans/w624b-harness-repair.md`, `plans/w551-counterfactual-kill-ledger.md`). **Manifest v3 predates both — needs a v4 addendum covering the W500/W600-series files** before the coordinator commit gates close DoD 4 | manifest v4 addendum (coordinator) + review-time enforcement at w153-v2-ordered integration review |

Post-w422 receipt deltas applied above (each `test -f`-verified 2026-10-06 by
W649 refresh-2): present — w316 (lane W316b), w473b, w425/w463, w340, w335,
w446, w395, w327, w398, w414, w185, w390, w464, w471, w317, w460, w332, w343,
w364, w366, w412, w324, w325, w323, w466, **w546, w547, w607, w616, w623,
w625c, w626c, w550, w624, w624b, w291**. Absent from disk, marked in flight /
not cited — w398b-as-separate-file (w398 is the landed corpus receipt), w345,
w415; **present but in-flight-cited only (verdicts PENDING in-receipt)** —
w551. The W468-era table is preserved verbatim in
`plans/w422-dod-rewalk-v4.md` plus that file's own post-w422 delta notes.
