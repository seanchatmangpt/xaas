# v26.10.6 Closure Plan — Receipts Index

Integration lane W184b; last synced W659d (set-equality sweep: 94 rows appended for the W543–W661 EU-AI-Act/AIRo/OS-19/20/21 wave + W700–W706 cross-project gap wave; W544's base carried forward) (set-equality sweep: rows added for w316/w453–w474 files W469's pass missed + the full W500–W541 EU-AI-Act wave).
One line per receipt file in this directory (except `_INDEX.md` itself); standing/deliverable
taken from each file's own header. Companion: `_LANES.md`, `_FRONTIER.md`, `_WIRING_MATRIX.md`.

## Definitions

| file | lane | type | standing / deliverable |
|---|---|---|---|
| `_LANES.md` | — | definition | lane map: mission (fleet wired through ~/xaas & ~/ash_surface, playwright-validated, v26.10.5 feature complete); integration base `feat/playwright-surface` @ d1db2b03; coordinator owns git/seams |
| `_FRONTIER.md` | — | definition | acceptance definition: per-repo acceptance criteria, standing vocabulary (all rows start UNKNOWN, filled only from lane receipts) |
| `_WIRING_MATRIX.md` | W164 | definition (DoD annex) | wiring matrix: pins re-verified live against mix.exs/mix.lock/router/ggen.toml/config.dev — `_FRONTIER.md` remains standing authority |
| `_CLOSURE_RECEIPT.md` | W243 | definition (closure receipt skeleton) | v26.10.6 final substantial receipt — skeleton; every field populated ONLY from receipt-cited evidence on disk (`_FRONTIER.md`, `_WIRING_MATRIX.md`, `_INDEX.md`, `_CLOSURE_PLAN.md` §5 DoD) |

## Fleet audits (r1–r11)

| file | lane | type | standing / deliverable |
|---|---|---|---|
| `r1-ggen.md` | R1 | audit r1 | ggen @ `feat/v26.10.5-release-cut` @ 000bffb8f — read-only fleet-convergence audit, fresh evidence this session |
| `r2-marketplace.md` | R2 | audit r2 | ggen-marketplace @ 93895f808 (clean, 305 packs) — audit + consumer-wiring plan; pin drift quantified for castle-bridge (1 commit) and ash-extension (31 commits) |
| `r3-igniter.md` | R3 | audit r3 | ggen_igniter 26.10.5 @ 7dbcdb3 — ash-manufacture-pack is fixture-only (test/, unreachable from hex): PARTIAL_ALIVE pack, UNSUPPORTED hex consumers |
| `r4-a2a.md` | R4 | audit r4 | ash_a2a @ feat/tck-vuln-hardening @ 07180bd3 (26.10.5, TCK 235/30/0 = 79.0%) — surface audit + wiring plan |
| `r5-pplan.md` | R5 | audit r5 | ash_pplan @ 414a393 (26.10.3, not yet 26.10.6; 1 dirty docs file inventoried) — read-only audit |
| `r6-ferroplan.md` | R6 | audit r6 | ferroplan @ c037876 (main) — dirty files are ggen receipt churn only; audit + wiring plan |
| `r7-zcode-cli.md` | R7 | audit r7 | zcode-cli @ 7fc62da (18 dirty paths) — fleet wiring plan; two-way xaas coupling documented |
| `r8-gymact.md` | R8 | audit r8 | gymact @ d3eb5e8 (3 dirty docs files) — BRCE/actuation/receipt layer; actuation HTTP surface real |
| `r9-beam4pm.md` | R9 | audit r9 | beam4pm @ 813eb92 (2,462 dirty files) — OTP-29 toolchain move, ex4pm regeneration, frontier pack unwired |
| `r10-wasm4pm.md` | R10 | audit r10 | wasm4pm @ 32deb59 — PARTIAL_ALIVE with typed gaps; branch MERGED as PR #659 into main @ a7352d818 |
| `r11-autofde-lab.md` | R11 | audit r11 | autofde-lab @ feat/doctrine-lab @ 2a3d064e — repo head ALIVE, xaas read path ALIVE, StatusLive surface ALIVE |

## Vectors (1–6)

| file | lane | type | standing / deliverable |
|---|---|---|---|
| `vector1-fenced-gates.md` | V1 | audit vector1 | fenced capabilities & unclosed proof gates; 103 forbid-floors are designed deny-by-default; TODO(ash_surface) fence possibly stale |
| `vector2-refusal-coverage.md` | V2 | audit vector2 | refusal exhaustion: ash_surface token-complete; xaas has 50 distinct REFUSED_* variants with no test coverage |
| `vector3-closure-receipt.md` | V3 | audit vector3 (closure receipt) | one-command un-ignore closure: host oracle tools all PRESENT, no installs needed |
| `vector3-ignored-suites.md` | V3 | audit vector3 | differential oracles & ignored conformance suites: 9 excluded tag classes in test_helper.exs; per-row un-ignore requirements |
| `vector4-gen-parity.md` | V4 | audit vector4 | generator parity: castle.ex injection drift YES; chicago/zcode zero-diff; ash_surface outputs absent (n/a) with no CI parity gate |
| `vector5-limits-lints.md` | V5 | audit vector5 | strict-flag compile VERIFIED GREEN both repos (exit 0, dep warnings only); stale lane build roots flagged |
| `vector6-docs-abi.md` | V6 | audit vector6 | docs/ABI registry reconciliation: ash_surface conformance MANIFEST re-hashed — NO DRIFT (11/11 files) |

## X-lanes (audit/inventory/plan)

| file | lane | type | standing / deliverable |
|---|---|---|---|
| `x1-playwright-inventory.md` | X1 | audit x1 | Playwright surface inventory: harness/env contract + per-spec gap plan |
| `x1b-playwright-runner.md` | X1b | audit x1b | runner audit: playwright 1.63.0 exact-match browsers installed; 23 tests in 5 healthy files |
| `x2-ash-surface.md` | X2 | audit x2 | ash_surface @ db5a8899 (26.10.1) — capability surface inventory, pipeline core tiered |
| `x3-xaas-web.md` | X3 | audit x3 | xaas web surface: LiveView inventory with routes + current playwright coverage |
| `x4-version-alignment.md` | X4 | audit x4 | version alignment across 13 repos vs 26.10.5 — per-file current/target/action table |
| `x5-ci.md` | X5 | audit x5 | per-repo CI workflow inventory + recent run status + wiring-gate plan |
| `x6-notes.md` | X6 | definition | frontier ledger scaffold: wrote _FRONTIER.md, acceptance per repo class, no git mutations |
| `x7-risk-register.md` | X7 | definition (risk register) | red-team risks ranked S0–S2; S0: "playwright-validate 12 of 13 repos" unfalsifiable — acceptance redefined per repo class |
| `x8-ash-surface-gen.md` | X8 | audit x8 | ash-surface generation path: PARTIAL_ALIVE — full-app generation works at EA35, artifacts verified on disk |

## Execution lanes (w6–w706)

| file | lane | type | standing / deliverable |
|---|---|---|---|
| `w6-igniter-pack-promotion.md` | W6 | execution w6 | ash-manufacture-pack promoted `test/fixtures` → `priv/ggen/ash-manufacture-pack` (git mv staged); 8 test files + 2 Path.join call sites updated; E2 marketplace-reject fence preserved (backfilled from lane report) |
| `w30-playwright-baseline.md` | W30 | execution w30 | BLOCKED (BUILD_BROKEN) — 0 specs executed; dev tree did not compile; compile failure IS the receipt |
| `w13-plug-refusals.md` | W13 | execution w13 | Plug & actuation refusal negative tests (backfilled by coordinator from lane completion report) |
| `w18-vkg-refusals.md` | W18 | execution w18 | VKG refusal negative tests (backfilled by coordinator from lane completion report) |
| `w35-autofde-oracle-gate.md` | W35 | execution w35 | autofde oracle gate: skip condition in yield_test.exs read; no source edits |
| `w38-igniter-credo.md` | W38 | execution w38 | ggen_igniter credo + format fixes: `sovereign_lease` with→case; `transition_log` extracted bump_marker/3 (backfilled from lane report) |
| `w40-zcode-release-workflow.md` | W40 | execution w40 | zcode-cli prepare-release failure DIAGNOSED (5 consecutive failures); fix NOT applied — needs release decision on main |
| `w41-pplan-facade.md` | W41 | execution w41 | Xaas.Bridges.PPlan facade rewrite onto `AshPPlan.A2A.Facade` @ pin 5f10c979 — start_or_adopt, two-task workflow, DurableAdapter :xaas_pplan |
| `w42-gymact-surface.md` | W42 | execution w42 | Xaas.Operations.GymactSurface fail-closed adapter over gymact FastAPI; actuate/4 external three-commit protocol behind actuation ledger; no :actuate_status contact |
| `w45-ferroplan-wasm-pin.md` | W45 | execution w45 | ferroplan wasm built (release, 51.68s) + artifact placed at pin location, staged-ready untracked for coordinator |
| `w46-zcode-stream-tests.md` | W46 | execution w46 | zcode-cli stream tests: correct unit entrypoint identified; plain `bun test` is NOT the unit suite (R7 instruction resolved to package script) |
| `w51-integration-verify.md` | W51 | execution w51 | Gate 1 compile BLOCKED (exit 1, TokenMissingError gymact_surface.ex:232); priv/ eacces permission defect disclosed |
| `w52-beam4pm-qualification.md` | W52 | execution w52 | beam4pm OTP-29 qualification: compile exit 0 green (677 resources); 3 test failures + 13 invalid groups root-caused to missing wasm artifact |
| `w53-ferroplan-bridge.md` | W53 | execution w53 | Xaas.Bridges.Ferroplan: sha256 pin 088d9c3b…, fail-closed on digest mismatch; wasmex 0.15.1 persistent_term compile-once cache (backfilled from lane report) |
| `w58-zcode-deps.md` | W58 | execution w58 | zcode-cli deps installed (pi-tui, cli-highlight) closing W46's 42-of-44 failure cluster |
| `w61-castle-bin-gate.md` | W61 | execution w61 | PARTIAL_ALIVE — pinned CASTLE_BIN materialized, gate run 2/3; 1 failure is pre-existing source defect; W36 blocker closed |
| `w68-full-suite.md` | W68 | execution w68 | BLOCKED — compile failure in external dep :ash_affidavit (capability-registry.json permission denied) |
| `w68b-full-suite.md` | W68b | execution w68b | full `MIX_ENV=test mix test` rerun on d1db2b03 (dirty tree, receipt-only) under pinned asdf toolchain; verbatim counts in receipt |
| `w67-castle-combined.md` | W67 | execution w67 | Castle batches 1–5 combined (backfilled by coordinator from lane completion report) |
| `w69-gates-rerun.md` | W69 | execution w69 | rerun-only lane: W51 blocked gates re-executed after permission context; no fixes |
| `w72-version-seams.md` | W72 | execution w72 | version seam alignment: xaas VERSION 26.10.2 → 26.10.6; wasm4pm package.json → 26.10.6 (backfilled from lane report) |
| `w70-playwright-full.md` | W70 | execution w70 | full Playwright run: webServer spawn failed 2/2 (env-class provenance xattr denial); manual server boots clean, suite ran against it |
| `w74-rust4pm-wasm.md` | W74 | execution w74 | beam4pm rust4pm WASM artifact built (exit 0, 27.16s) closing W52 residual |
| `w75-ex4pm-baseline.md` | W75 | execution w75 | ex4pm baseline @ 9f7aecd under OTP-29 toolchain; verbatim counts; pin baselining, no fixes |
| `w76-ash-r2rml-baseline.md` | W76 | execution w76 | ash_r2rml baseline: 998 tests, 0 failures, 9 skipped (verbatim) |
| `w77-ash-a2a-baseline.md` | W77 | execution w77 | ash_a2a baseline on feat/tck-vuln-hardening @ 07180bd3 as upper-bound proxy for pin v26.10.4 @ 86214551: 3707/3708 pass (1 load-dependent timeout flake) |
| `w78-autofde-baseline.md` | W78 | execution w78 | autofde-lab baseline via `just test` (pytest -n 4, 15 excludes); heavy suites NOT run (disclosed) |
| `w79-gymact-dcm.md` | W79 | execution w79 | gymact DCM standing ladder @ d3eb5e8 (canonical checkout): DCM flow receipt; standing per file header |
| `w80-pack-repin-diff.md` | W80 | execution w80 | ash-extension re-pin diff baa5f117 → 3ddbfeb7 (31 commits, read-only); coordinator to re-confirm target SHA |
| `w81-ggen-cargo-check.md` | W81 | execution w81 | ggen @ 000bffb8f `cargo check --workspace` (2m 13s) — Cargo.lock settled |
| `w82-oracle-rerun.md` | W82 | execution w82 | vector-3 oracle suites rerun under settled tree + in-flight ggen_igniter modifications; receipt-only |
| `w83-stripe-seller-verify.md` | W83 | execution w83 | endpoint_body_limit tests realigned to typed `Plug.Parsers.RequestTooLargeError`; seller verify fixes (backfilled from lane report) |
| `w85-mix-generator-parity.md` | W85 | execution w85 | mix-generator parity: zcode_event_registry byte-identical; 3 sa2a surfaces formatting-only drift; 1 permanent-UNKNOWN target |
| `w87-ci-validation.md` | W87 | execution w87 | 21 workflow YAML files validated 21 PASS / 0 FAIL + mock gate scan |
| `w89-gymact-cwd-fix.md` | W89 | execution w89 | gymact ggen CWD pollution fix: ggen ≥ 26.9.28 wrote `.clap-noun-verb/` into CWD (backfilled from lane report) |
| `w90-repin-verify.md` | W90 | execution w90 | BLOCKED — ash-extension re-pin sync refuses at tip (falsifier N/A, no generation occurred); ash_surface working tree, no commits |
| `w91-permission-sweep.md` | W91 | execution w91 | 17-repo chmod sweep (u+rwX): damaged repos REPAIRED, rest clean; no content changes |
| `w94-wasm4pm-flake.md` | W94 | execution w94 | wasm4pm CI flake fixed: float-boundary epsilon bug in the test itself (0.30000000000000004) |
| `w95-gymact-full-suite.md` | W95 | execution w95 | gymact full pytest suite: 2356 passed / 41 skipped / 10 xfailed, exit 0 (3 runs); all 41 skips named-standing class |
| `w99-next-read-fix.md` | W99 | execution w99 | next-read Playwright fix: clicks fired before LiveView websocket connected (`networkidle` ≠ phx-connected) (backfilled from lane report) |
| `w102-ash-surface-full-suite.md` | W102 | execution w102 | ash_surface full suite: tracked tests effectively clean (16 failures confined to ignored scratch files); JS surface green 367/367; W43/W66 lane surfaces green |
| `w103-prod-compile.md` | W103 | execution w103 | local MIX_ENV=prod mix compile --force --warnings-as-errors under pinned toolchain; raw log retained |
| `w105-marketplace-baseline.md` | W105 | execution w105 | ggen-marketplace baseline on W48-modified tree: gates ALIVE; profile verifiers exit 0 (MSCT ALIVE, Enterprise Kudru PARTIAL_ALIVE); 1956 passed |
| `w107-schema-drift.md` | W107 | execution w107 | receipt-schema v2/v1 drift adjudication + validator fix: oracle corpus 27/56 → 52/56 (final rerun); residual 4 typed BLOCKED(machinery_absent); dual-version law ALIVE |
| `w108-sibling-build.md` | W108 | execution w108 | ggen_igniter sibling rebuild fixing W82's gated-suite skips; 1555 green, credo clean |
| `w109-a2a-v1-court.md` | W109 | execution w109 | /a2a/v1 ExUnit court through real router → AshA2A.Protocol.Plug → NextRead agents; structural JSON asserts, all courts passing |
| `w106-mix-task-stragglers.md` | W106 | execution w106 | mix task refusal-convention stragglers: `xaas.ash_surface.ex` + `xaas.self_digest.ex` converted to `REFUSED(<atom>, detail:)`/`render_refusal/1` (backfilled from lane report) |
| `w110-autofde-import.md` | W110 | execution w110 | autofde-lab ImportError diagnosed (namespace-package signature) and eliminated: 34+ → 0 occurrences |
| `w111-pw-interim.md` | W111 | execution w111 | interim Playwright run over 6 repaired spec classes vs live :4000 server; exit 1, per-file JSON counts recorded |
| `w112-witness-nextread-pw.md` | W112 | execution w112 | witness + next-read Playwright verification vs pre-existing live :4000 server (HTTP 200 verified, reused not started); per-file results in receipt |
| `w113-a2a-pw.md` | W113 | execution w113 | a2a/mcp/ggen-workbench Playwright: token branch 11 passed / 7 failed (BLOCKED environment: pending migrations); tokenless 3/15 = honest 503 fail-closed floor |
| `w114-commit-plan.md` | W114 | execution w114 (plan) | integration commit plan: repo dependency order, do-NOT-commit flags (pycache, lane residue) — no git mutations |
| `w118-pw-final.md` | W118 | execution w118 | Playwright final: full suite fresh webServer boot + globalSetup catalog (13 packs) + witness seed — 97 total: 62 passed / 32 failed / 3 skipped (2.0m) |
| `w116-mu-on-o-adjudication.md` | W116 | execution w116 | mu_on_O adjudication (backfilled by coordinator from lane completion report) |
| `w121-checkpoint-conflict.md` | W121 | execution w121 | external_checkpoint_conflict reachability (backfilled by coordinator from lane completion report) |
| `w117-pw-residuals.md` | W117 | execution w117 | Playwright residual fixes: dev-routes Dashboard `.first()` scope; ash-admin nav visible-filter (backfilled from lane report) |
| `w120-web-suite.md` | W120 | execution w120 | web layer suite: 347 passed, 1 excluded (verbatim, 24.5s) |
| `w122-igniter-final.md` | W122 | execution w122 | ggen_igniter final confirmation: credo + pycache gates PASS; mix test 1555 tests / 1 failure (W38 format moved anti-vacuity anchor) — no fix per lane instructions |
| `w126-pack-gate-fix.md` | W126 | execution w126 | pack gate fix in ggen-marketplace @ 93895f8 (edits UNCOMMITTED); pack pin consumed by ash_surface = 3ddbfeb7 per ggen.toml re-pin |
| `w125-epa-sweep.md` | W125 | execution w125 | EP-A/AC-04 consistency sweep: whether EP-A references beyond `semantic_drive_anchor` needed pinning (backfilled from lane report) |
| `w129-gymact-crown.md` | W129 | execution w129 | gymact DCM-018 witnessed-crown attempt: full DCM flow run to standing ALIVE with receipt; crown remains structurally un-premarkable (CROWN_CANNOT_BE_PREMARKED_ALIVE enforced) |
| `w131-operations-suite.md` | W131 | execution w131 | operations layer + mix task suite on d1db2b03: 103 passed, 0 failed, 20 excluded — ALIVE |
| `w132-verify-rehearsal.md` | W132 | execution w132 | verify_and_commit rehearsal: compile stage OK, stages 2+ BLOCKED by ash_surface dep compile failure; test stage NOT RUN |
| `w135-witness-pw.md` | W135 | execution w135 | BLOCKED — witness Playwright webServer boot failed (:ash_surface dep compile, ash_a2a/resource.ex:46); 0 tests executed |
| `w136-migration-check.md` | W136 | execution w136 | migration safety check 20261006000000_repair_witness_certified_receipts: conditional-by-construction verified (fresh-DB no-op) |
| `w139-e4-adjudication.md` | W139 | execution w139 | W139-E4 adjudication: post-W139/W142 targeted sjira-layer verification (ard_court, v26_9_23_goal, stop_court) with real commands + results |
| `w142-e5-e6.md` | W142 | execution w142 | E5/E6 isolation hardening (backfilled by coordinator from lane completion report) |
| `w144-inventory-v2.md` | W144 | execution w144 | Inventory v2 closure plan (backfilled by coordinator from lane completion report) |
| `w141-drift-regen.md` | W141 | execution w141 | drift-regen E3: `mix xaas.ash_surface` FAILED (UndefinedFunctionError AshA2A.Dsl.dsl_patches/0); persisting failures classified, pinned toolchain |
| `w146-chicago-suite.md` | W146 | execution w146 | BUILD_BROKEN — chicago suite compile exit 1, 0 tests executed; confirmed no candidate-vs-successor standing assertion drift in test/xaas/chicago |
| `w148-bridges-ultracode.md` | W148 | execution w148 | BLOCKED(BUILD_BROKEN) — bridges + ultracode suites gated on dep `ash_surface` / ash_a2a 26.10.4 compile failure; pre-existing, not lane-introduced |
| `w149-validator-health.md` | W149 | execution w149 | validate_receipt.py health check post-W107 `known` diagnostic edit (unused-variable fix); session state at d1db2b03 |
| `w151-dev-migrate.md` | W151 | execution w151 | dev DB migration convergence: xaas_dev brought current after W113 PendingMigrationError; migrate only, no rollback/drop, no git |
| `w153-commit-plan-v2.md` | W153 | execution w153 (plan) | integration commit plan v2 (W114 refresh): verbatim `git status --porcelain` inventories 2026-10-06; deltas/corrections per repo — no git mutations |
| `w154-chicago-rerun.md` | W154 | execution w154 | Chicago suite rerun (stub; full record: 150 passed / 0 failures post-collision-fix, see file) |
| `w163-bridges-rerun.md` | W163 | execution w163 | Bridges rerun (stub; full record: bridges + origin_authority + anchor 24 passed, see file) |
| `w155-registry-receipts.md` | W155 | execution w155 | v26.9.23 stop-court registry receipts (E2 second half) CLOSED test-side: test files only, no lib edits, no git |
| `w165-wasm4pm-bumps.md` | W165 | execution w165 | wasm4pm version convergence 26.9.28 → 26.10.6: package.json + pnpm-lock.yaml + receipt only (14 files, version field only) |
| `w167-pg-saturation.md` | W167 | execution w167 | Postgres connection saturation diagnosis (FATAL 53300) in test runs; test-env only, prod untouched, no git |
| `w168-specimen-disposition.md` | W168 | execution w168 | disposition of 24 untracked ash_surface court/specimen test files + fixture/burn_in tree (W153-v2 sync-installer outputs); gate result in receipt |
| `w173-boot-chain.md` | W173 | execution w173 | boot-chain validation: internal-api/a2a-v1/witness Playwright gates on pre-run tree; no edits, no git |
| `w175-shared-build.md` | W175 | execution w175 | shared `_build/test` reconciliation resolving W136's disclosed ash_surface path-dep compile failure (unblocked W132's ecto.migrations check) |
| `w176-refusal-delta-recount.md` | W176 | execution w176 | refusal-coverage delta recount (vector-2 authoritative metric): read-only replay on lib/ + test/ |
| `w180-seed-class.md` | W180 | execution w180 | seed-dependent failure class closure (W70 class): stale :4000 beam killed (authorized), global-setup catalog 13 packs + witness seed observed |
| `w188-diag-removal.md` | W188 | execution w188 | DIAG_CLAIM debug instrumentation removed from ash_a2a `lib/ash_a2a/command_bus.ex` (untracked working-tree edit dispositioned) |
| `w191-final-hazards.md` | W191 | execution w191 (plan) | final do-not-commit hazard list: fresh per-repo `git status --porcelain`, DO-NOT-COMMIT/PARKED/COMMIT-eligible classification; supersedes W153-v2 — no git mutations |
| `w196-semantics-suite.md` | W196 | execution w196 | semantics suite on d1db2b03: 29 passed (verbatim) under pinned asdf toolchain |
| `w197-telemetry-suite.md` | W197 | execution w197 | telemetry suite post-W142: 33 passed (verbatim) under pinned asdf toolchain |
| `w198-sa2a-suite.md` | W198 | execution w198 | sa2a suite post-W142: 102 passed / 18 skipped / 1 excluded, 0 failures; W49 court.ex + W142 route_test flips hold; standing ALIVE |
| `w20-ash-pplan-adjudication.md` | W20 | execution w20 | ash_pplan failure adjudication (interim at backfill): 55 dirs with stripped owner execute bit (OS-11 fleet fault class, same as W91/W75/W151) restored to verified fixpoint 0 non-traversable; final verdict pending |
| `w104-tag-runs.md` | W104 | execution w104 | two bounded un-ignored tag classes not needing castle/kind run as specified; no fixes, no git |
| `w128-oracle-final.md` | W128 | execution w128 | oracle courts final rerun: `mix test` over v26_9_23_goal + xaas_stop_court (GGEN_IGNITER_DIR set) (backfilled from lane report) |
| `w133b-compile-prose-stop.md` | W133b | execution w133b | STOP verdict: compile_prose → observe_prose migration cannot proceed without faking equivalence (backfilled from lane report) |
| `w150-auth-floor-fixes.md` | W150 | execution w150 | auth floor fixes: /api/workbench + /a2a parse floor (backfilled from lane report) |
| `w161-order-bound.md` | W161 | execution w161 | E3-37 order-bound adjudication (backfilled from lane report) |
| `w169-marketplace-regression.md` | W169 | execution w169 | post-W126 marketplace regression sweep (backfilled from lane report) |
| `w171-app-gaps.md` | W171 | execution w171 | app gaps (zcode-cli fabric surface); post-W171 standalone re-run: 6 adversarial courts + typed -32603 fail-close added |
| `w174-ontop-health-typing.md` | W174 | execution w174 | ontop health-check typing, config-gated (backfilled from lane report) |
| `w183-token-revocation-findings.md` | W183 | execution w183 | token revocation court: `test/xaas/accounts/token_revocation_test.exs` — 4 tests passing on real Ecto sandbox + real Ash + real AshAuthentication JWTs (accounts dir 23 passed) |
| `w192-ultracode-rerun.md` | W192 | execution w192 | post-W161 targeted ultracode rerun: classify/fix the 3 pre-existing failures W161 named; no lib edits, no git |
| `w205-router-regression.md` | W205 | execution w205 | router regression cover of W150 endpoint.ex changes (workbench pipeline reorder — token floor before `:accepts`, plus a2a parse floor); read-only, three real runs |
| `w210-vacuity-sweep.md` | W210 | execution w210 | vacuity sweep over failure-evidence tests (W195 class) across the three named files |
| `w214-staging-sequence.md` | W214 | execution w214 (plan) | final xaas staging sequence: 212-line `git status --porcelain` resolved into path-keyed groups + exclusion list, no orphans; READ-ONLY, no git mutations |
| `w216-igniter-final2.md` | W216 | execution w216 | ggen_igniter final full-suite gate on fully-modified tree (W6 promotion + W38 credo/format + anchor repoint); read-only gate, no fixes, no git |
| `w218-post-residue.md` | W218 | execution w218 (W231b) | post-residue verification — witness unit gate |
| `w219-ultracode-full.md` | W219 | execution w219 | full ultracode-dir test receipt @ HEAD d1db2b03 |
| `w220-marketplace-igniter.md` | W220 | execution w220 | targeted test receipt: W115-touched marketplace/igniter resources; verification only, no fixes, no git |
| `w221-conference-a2a.md` | W221 | execution w221 | targeted test receipt: conference + a2a (W115-touched resources) under pinned asdf toolchain |
| `w223-verify-stages2.md` | W223 | execution w223 | re-run of W132's 4 BLOCKED stages (format, codegen --check, ecto.migrations; test scoped out per assignment), compile green per w175 |
| `w224-drift-authority.md` | W224 | execution w224 | drift-authority receipt: priv/ash_surface on-disk state vs HEAD d1db2b03; no regen runs, no git mutations |
| `w225-repo-staging.md` | W225 | execution w225 (plan) | final staging sequences for 10 non-xaas repos from fresh per-repo status + W191 hazard lists + W153-v2 grouping (conflicts resolved in favor of W191) |
| `w226-sjira-dir.md` | W226 | execution w226 | sjira dir post-W139 verification: full `test/xaas/sjira` minus externals after W139 generate.py + fixtures changes |
| `w228-mix-tasks-dir.md` | W228 | execution w228 | `mix test test/mix` dir-level verification, command repeated 5x |
| `w230-r2rml-skew.md` | W230 | execution w230 | ash_r2rml API skew adjudication — ADJUDICATED, gate green |
| `w236-refusal-capstone.md` | W236 | execution w236 | consolidated refusal-suite capstone: 12 refusal/court test files (castle batches 1–6, r2rml, vkg, actuation, token revocation, plug, body limit) under pinned asdf, MIX_ENV=test |
| `w244-format-regression.md` | W244 | execution w244 | format regression check of most-touched suites after W237 format-only pass (39 files); no fixes, no git |
| `w247-codegen.md` | W247 | execution w247 | codegen closure finding |
| `w249-self-digest-isolation.md` | W249 | execution w249 | self_digest test isolation fix |
| `w253-format-regression2.md` | W253 | execution w253 | format regression coverage of remaining 5 files after W237 (39 files) + W244 (6 test files) |
| `w258-migration-fix.md` | W258 | execution w258 | migration duplication verification — task superseded by W247 |
| `w264-fixtureonly-markers.md` | W264 | execution w264 | `aex:fixtureOnly` markers for ash-extension-pack worked examples (OS-13 durable fix); ggen-marketplace `packs/ash-extension-pack/ontology.ttl` only |
| `w158-suite-with-token.md` | W158 | execution w158 | full `MIX_ENV=test mix test` WITH token (INTERNAL_API_TOKEN=dev-e2e-token via wrapper, pinned asdf) @ HEAD d1db2b03 — closes W68b E1 class |
| `w252-post-fix-e2e.md` | W252 | execution w252 | post-W171-fix consolidated e2e receipt: execution-fabric, system-deep, dev-routes, ash-admin-matrix, witness, full_surface via playwright-managed webServer with token passthrough |
| `w261-ash-a2a-final.md` | W261 | execution w261 | ash_a2a final full-suite gate on fully-modified tree (W130 authzen monotonic-TTL + coordinator test_helper sweep/naming + command_bus timeout tag) |
| `w273-sjira-root.md` | W273 | execution w273 | test/sjira root-dir receipt (post-format, vacuity-fixed): `test/sjira/v26_9_23_goal_test.exs`; receipt only, no fixes, no git |
| `w215-final-full-suite.md` | W215 | execution w215 | final full-suite measurement receipt (two runs): 3144/3230 then 2811/3231 passed, 86 then 420 failed; full run-2 log at /tmp/w215-full-suite.log; mock gate run twice |
| `w245-property-token.md` | W245 | execution w245 | property suite re-run WITH `INTERNAL_API_TOKEN`: run 1 truncated (231 failures, not reproducible); run 2 full log `/tmp/w245_property_full.log` isolating real failures from W104's token-EnvError class |
| `w251-final-suite.md` | W251 | execution w251 | definitive full-suite receipt (W158 mandate): run 2 = 2985/3232 passed, 247 failed, 36 skipped, 91 excluded (verbatim); full 4497-line log at /tmp/w251-suite-full.log; mock gate verbatim |
| `w259-pw-definitive.md` | W259 | execution w259 | definitive Playwright receipt: 87 passed / 9 failed / 2 skipped (98 executed, ~1.5 min) on fresh webServer boot, PW 1.63.0; per-file counts + raw log /tmp/w259-full.log |
| `w260-ground-truth.md` | W260 | execution w260 | ground-truth curl probes vs fresh beam booted with exact prescribed command: auth floor 401 typed JSON (SERVER-TRUTH, not 406), a2a wire parse error verdicts; verbatim transcripts, port hygiene disclosed |
| `w270-a2a-sse.md` | W270 | execution w270 | a2a-v1 SSE lane receipt (W297): W270 SSE work committed, tree clean vs HEAD; ran 3 passed / 4 failed vs live :4000 beam (read-only, PID 55861 reused) — malformed-JSON -32700 vs -32600, SSE smoke among failures |
| `w280-async-env-isolation.md` | W280 | execution w280 | async env isolation (INTERNAL_API_TOKEN, test files only): poisoner = chicago_authority_courts (only async:true env mutator), leaker = gymact_surface refusal tests never restoring env; reproduced 7-failure coupling |
| `w281-class-d.md` | W281 | execution w281 | Class D drift adjudication (10 W158 failures): all stale-beam, zero real drift — every named function exists at exact arity in current tree; seed-281 reruns green |
| `w283-sjira-post-w139.md` | W283 | execution w283 | sjira dir receipt post-W139 origin_authority requirement + SJ-001 fixture regen: verbatim pass (7.7s) with excludes; no fixes, no git |
| `w284-accounts-operations.md` | W284 | execution w284 | accounts + operations combined gate @ d1db2b03: 72 passed, 5 excluded — ALIVE; W183+W42+W23 surfaces coexist; full suite + mock gate out of scope (disclosed falsifiers) |
| `w292-quiescence.md` | W292 | execution w292 | pre-quiescence read-only snapshot: zero lib/test/config/priv writes in last 15 min; 18 beam.smp + 2 wrappers inventoried per PID/cwd — active ultracode mix test workloads |
| `w310-lane-ports.md` | W310 | execution w310 | playwright.config.cjs lane-lease port fix (W279 cross-lane port-race): single lane port derived from `PW_PORT` (default 4000), threaded through webServer.port, BOOT probe, and webServer.env.PORT; concurrent lanes must set distinct PW_PORT |
| `w227-ultracode-dir.md` | W227 | execution w227 | ultracode dir verification receipt — combined ultracode-dir verification |
| `w248-subprocess-token.md` | W248 | execution w248 | subprocess suite re-run WITH `INTERNAL_API_TOKEN` |
| `w289-final-dod-suite.md` | W289 | execution w289 | final full-suite DoD-1 measurement post-W280 async env-isolation fix; read-only, no fixes |
| `w290-cross-dir.md` | W290 | execution w290 | cross-dir consolidation run (chicago + sjira + ultracode + test/mix) |
| `w295b-definitive-suite.md` | W295b | execution w295b | definitive full-suite measurement on clean build root @ d1db2b03 |
| `w299-pw-final2.md` | W299 | execution w299 | definitive final Playwright receipt (working tree, no fixes applied by lane) |
| `w299b-server-death.md` | W299b | execution w299b | server-death diagnosis |
| `w300-final-suite.md` | W300 | execution w300 | THE definitive final full-suite receipt (post-everything) |
| `w301-env-isolation-final.md` | W301 | execution w301 | env isolation, execution_fabric_controller_test — FINAL receipt |
| `w302-pw-post-w270.md` | W302 | execution w302 | full Playwright rerun post-W270/W310 |
| `w310d-final-suite.md` | W310d | execution w310d | final full-suite receipt (post-W305 router mount + all wave fixes) |
| `w310g-pw-final.md` | W310g | execution w310g | final full Playwright receipt |
| `w311-sjira-final.md` | W311 | execution w311 | combined sjira final receipt |
| `w313-sjira-sem-final.md` | W313 | execution w313 | final sjira-root + semantics receipt (post-format) |
| `w315-final-dod-suite.md` | W315 | execution w315 | final DoD-1 suite receipt (TRUE DoD-1 measurement) |
| `w317-pw-final-tokened.md` | W317 | execution w317 | PW final tokened browser-rung receipt |
| `w321-unreachable-reverify.md` | W321 | execution w321 | structural unreachability re-verification (DoD 3, `_CLOSURE_PLAN.md` §2) |
| `w322-zero-config-posture.md` | W322 | execution w322 | zero-config refusal/safety posture audit (EU AI Act mandate, vector c) |
| `w324-frontier-audit.md` | W324 | execution w324 | frontier DoD-6 audit |
| `w327-ci-gates-draft.md` | W327 | execution w327 | closure-gates workflow draft (DoD 2 / P2-2) |
| `w328-docs-sweep-verify.md` | W328 | execution w328 | P2-6 docs staleness sweep, falsifier re-run (read-only leg) |
| `w330-receipt-flip-plan.md` | W330 | execution w330 (plan) | PENDING→CLOSED flip plan for `_CLOSURE_RECEIPT.md` + DoD re-walk v3 evidence bundle |
| `w331-wasm4pm-ci-assessment.md` | W331 | execution w331 | wasm4pm CI-exact-head assessment (DoD 6 wasm4pm leg) |
| `w336-digest-manifest.md` | W336 | execution w336 | digest manifest for machine registries (P2-5) — DONE |
| `w338-plan-residual-rows.md` | W338 | execution w338 | §1 residual rows re-adjudication |
| `w339-pin-alignment.md` | W339 | execution w339 | pin alignment — x4 SEAM audit @ xaas feat/playwright-surface |
| `w340-banned-pattern-sweep.md` | W340 | execution w340 | banned-pattern / non-negotiables regression sweep (incl. mock gate) |
| `w320-anti-vacuity-audit.md` | W320 | execution w320 | anti-vacuity mutation audit — spot-verify, 6 mutants (private build root _build-laneW320) |
| `w323-dod7-provenance.md` | W323 | execution w323 | DoD 7 provenance map — review-time admission map; every working-tree diff traced |
| `w325-gymact-e2e-falsifier.md` | W325 | execution w325 | gymact end-to-end falsifier receipt (gymact pytest courts + xaas e2e spec) |
| `w326-ash-surface-c-fixtures.md` | W326 | execution w326 | ash_surface DoD 3 C′/C″ fixtures receipt @ feat/playwright-surface (no commit) |
| `w329-unignored-suites.md` | W329 | execution w329 | DoD 1: un-ignored bounded suites — real run counts under pinned asdf + lane build root |
| `w333-ash-onetime-diagnosis.md` | W333 | execution w333 | ash_onetime `:store_invariant` diagnosis (OS-12 operator decision memo), ash_onetime hex 1.2.3 |
| `w334-head-drift-witness.md` | W334 | execution w334 | HEAD drift witness (DoD 4): scratch materialization via git archive @ d1db2b03 |
| `w335-strict-compile-fresh.md` | W335 | execution w335 | DoD 2 local legs: strict compile at fresh + dirty HEAD (xaas + ash_surface) |
| `w337-ash-policy-floor.md` | W337 | execution w337 | Ash policy floor audit over the v26.10.6 convergence diff (read-only, no fixes) |
| `w342-e2e-coverage-map.md` | W342 | execution w342 | E2E coverage map (P3-2): URL paths extracted from all 22 e2e specs vs LiveView inventory |
| `w344-health-503-diagnosis.md` | W344 | execution w344 | `/internal-api/health` 503-with-token residual diagnosis (read-only) |
| `w346-os-memos.md` | W346 | execution w346 | operator decisions OS-2 / OS-3 / OS-6 typed lift memos |
| `w348-ash-surface-fleet-falsifiers.md` | W348 | execution w348 | ash_surface fleet falsifiers G1–G5 execution receipt @ db5a8899, version 26.10.6 |
| `w351-changelog-backfill.md` | W351 | execution w351 | changelog window backfill (P2-6 S7) — DONE; CHANGELOG.md append-only |
| `w353-fenced-rows-disposition.md` | W353 | execution w353 | §1 fenced rows typed dispositions (read-only evidence pass) |
| `w354-commit-ready-freshness.md` | W354 | execution w354 | commit-ready freshness receipt (read-only audit, per-item status) |
| `w355-os13-pack-markers.md` | W355 | execution w355 | OS-13 staging: pack marker census + durable-fix draft (PROPOSED text only, no pack edits) |
| `w356-zcode-contract-shas.md` | W356 | execution w356 | zcode-cli contract sha re-verification (WP-C staging integrity) |
| `w357-marketplace-validate.md` | W357 | execution w357 | ggen-marketplace WP-E re-witness receipt (prior 1956/0 ×2 stands) |
| `w360-wiring-matrix-reverify.md` | W360 | execution w360 | wiring matrix re-verification: every W164 edge re-checked vs live tree @ d1db2b03 |
| `w361-ggen-wpd-legs.md` | W361 | execution w361 | ggen WP-D verification legs re-witness @ 000bffb8f (read-only) |
| `w362-catalog-determinism.md` | W362 | execution w362 | P3 boot-path catalog determinism receipt (`e2e/global-setup.cjs --catalog` probe) |
| `w365-toolchain-coherence.md` | W365 | execution w365 | toolchain coherence precondition audit (DoD 1): fleet-wide pin sweep vs elixir 1.20.2-otp-28 / erlang 28.5.0.2 |
| `w332-sibling-gate-reconfirm.md` | W332 | execution w332 | sibling gate reconfirm (DoD 5 CLI rung freshness): prior receipt-backed greens reconfirmed at current heads |
| `w343-igniter-freshness.md` | W343 | execution w343 | ggen_igniter CLI rung freshness receipt — ALIVE (all gates green) |
| `w347-workbench-matrix.md` | W347 | execution w347 | ggen-workbench auth-floor re-witness: tokenless answers typed 401, never 406 (W299c forward-scope reorder) |
| `w349-cloak-key-guard.md` | W349 | execution w349 | CLOAK_KEY env-override guard test (closure row 5, P1-4 test-only boundary) over committed vault placeholder |
| `w350-registry-drift-guard.md` | W350 | execution w350 | generated-registry drift guard (§1 row 17): test-only drift guard test, zero lib/ changes |
| `w358-composite-gate.md` | W358 | execution w358 | composite gate (verify_and_commit) dry-run witness with per-stage classification |
| `w359-chicago-presence-pin.md` | W359 | execution w359 | Chicago presence pin (§1 row 8, RESOLVE-BY-TEST) at d1db2b03 |
| `w363-ash-onetime-doctor.md` | W363 | execution w363 | ash_onetime doctor baseline (OS-12 read-only evidence), ash_onetime hex 1.2.3 |
| `w364-beam4pm-freshness.md` | W364 | execution w364 | beam4pm freshness gate at current head 813eb92 (WP-F, read-only) |
| `w366-ash-a2a-head-gate.md` | W366 | execution w366 | ash_a2a HEAD gate (re-pin adjudication evidence) |
| `w367-capability-coverage.md` | W367 | execution w367 | capability coverage machinery + fail-closed ingest witness |
| `w368-sse-residual-probe.md` | W368 | execution w368 | SSE residual probe: does `message/stream` push incremental SSE over the wire (read-only diagnosis) |
| `w369-r-projection-flunk.md` | W369 | execution w369 | r_projection silent skip → presence flunk (closure row 27, P1-5) |
| `w371-post-quarantine-gate.md` | W371 | execution w371 | post-quarantine gate (OS-13 stray installer files) on ash_surface canonical checkout |
| `w372-autofde-wph-legs.md` | W372 | execution w372 | WP-H verification legs freshness re-witness after dev.exs re-points (§1 row 20) |
| `w373-gymact-wpj.md` | W373 | execution w373 | gymact WP-J version metadata — NO-OP: version coherence already holds at 26.10.6 |
| `w374-optin-census.md` | W374 | execution w374 | DoD 1 opt-in census of the 5 vector3 opt-in tags (@tag/@moduletag/@describetag carriers) |
| `w375-receipt-hygiene.md` | W375 | execution w375 | receipt hygiene audit across v26.10.6 receipts |
| `w376-diataxis-tutorial-howto.md` | W376 | execution w376 | diataxis tutorial(s)/ + how-to/ staleness sweep (P2-6 residual) |
| `w377-pin-integrity.md` | W377 | execution w377 | pin integrity audit (replay-identity precondition) from mix.lock/mix.exs pins |
| `w378-vkg-kill.md` | W378 | execution w378 | REFUSED_VKG_EMPTY_CATALOG anti-vacuity (W320 gap 1): typed structural unreachability, no kill test written |
| `w379-actuation-kill.md` | W379 | execution w379 | actuation `:external_admission_identity_mismatch` anti-vacuity (W320 gap 2) |
| `w380-castle-kernel-witness.md` | W380 | execution w380 | castle_kernel opt-in class evidence (DoD 1) |
| `w381-pw-skips-adjudication.md` | W381 | execution w381 | Playwright skip adjudication vs w317's 96 passed / 0 failed / 2 skipped |
| `w382-anti-vacuity-r2.md` | W382 | execution w382 | anti-vacuity mutation audit, round 2 (3 mutants) |
| `w383-doc-map-sweep.md` | W383 | execution w383 | doc map sweep receipt (P2-6, read-only) |
| `w385-conformance-court.md` | W385 | execution w385 | A2A v1 conformance court receipt (Y-primitive, one-command machine report) |
| `w387-ontology-staleness.md` | W387 | execution w387 | ex4pm ontology staleness task witness (v26.10.6 convergence) |
| `w388-kind-witness.md` | W388 | execution w388 | DoD 1 opt-in evidence: `:kind` class witness (v26.10.6) |
| `w389-link-check.md` | W389 | execution w389 | evidence-link audit (W230-class refresh, read-only) |
| `w390-sync-output-staging.md` | W390 | execution w390 | SYNC-OUTPUT staging for the castle-bridge commit: git-archive scratch + ggen sync run EXIT=0 (278s) |
| `w391-pw-contention.md` | W391 | execution w391 | PW contention adjudication: w381's 10 unexpected failures vs w317's 96/0 |
| `w392-os12-migration-staging.md` | W392 | execution w392 | OS-12 sanctioned migration staging (operator review bytes) |
| `w393-cloak-prod-wiring.md` | W393 | execution w393 | Cloak prod wiring trace (OS-17 evidence completion, read-only) |
| `w395-format-rewitness.md` | W395 | execution w395 | format rewitness receipt (v26.10.6) |
| `w396-zeroconfig-delta.md` | W396 | execution w396 | zero-config posture delta re-audit (post-W322 env-reading changes) |
| `w399-runbook-freshness.md` | W399 | execution w399 | runbook freshness re-verify (2026-10-06, lane W399) |
| `w413-marketplace-toolchain.md` | W413 | execution w413 | ggen-marketplace toolchain pin (.tool-versions) receipt |
| `w386-stress-witness.md` | W386 | execution w386 | stress-class opt-in evidence (DoD 1), lane build root `_build-laneW386` removed after runs |
| `w401-refusal-ledger-jcs.md` | W401 | execution w401 | CRO Stage-3 refusal-ledger JCS export (backfill stub; artifact is the evidence) |
| `w402-stage4-entitlement-verification.md` | W402 | execution w402 | CRO Stage-4 entitlement-flow verification over ggen-marketplace (read-only) + xaas @ d1db2b03 |
| `w403-ash-surface-refusal-ledger.md` | W403 | execution w403 | CRO ash_surface refusal ledger (read-only, no commit); artifact `docs/cro/artifacts/ash-surface-refusal-ledger-v26.10.6.md` |
| `w404-fiduciary-briefing.md` | W404 | execution w404 | CRO Stage-2 fiduciary briefing @ d1db2b03 (backfill stub) |
| `w405-evidence-claims-index.md` | W405 | execution w405 | CRO evidence–claims index @ d1db2b03 (backfill stub) |
| `w406-cycle0-dryrun.md` | W406 | execution w406 | CRO cycle-0 dry run @ d1db2b03 (backfill stub) |
| `w407-agent-obliviousness-demo.md` | W407 | execution w407 | CRO Stage-3 agent-obliviousness demo @ d1db2b03 (backfill stub) |
| `w408-kind-typed-skips.md` | W408 | execution w408 | kind-class typed skips (w155 convention) — 4 kind-class files emit typed skips offline instead of failing loudly |
| `w412-cnv-deploy-witness.md` | W412 | execution w412 | cnv_deploy opt-in-class witness (DoD 1) — completes witness set: kind w388, stress w386, castle_kernel w380, cnv_deploy |
| `w414-empty-bearer-kill.md` | W414 | execution w414 | empty-bearer guard mutation kill — closes w382 gap: `byte_size(token) > 0` guard in require_internal_api_token.ex was vacuous as tested |
| `w416-web-slice.md` | W416 | execution w416 | final-tree web regression net (test/xaas_web/ + test/xaas/accounts/), cold lane build `_build-laneW416` deleted after run |
| `w418-release-snapshot-court.md` | W418 | execution w418 | release_snapshot verify court (writes only this file + private lane build root, removed at close) |
| `w422-dod-rewalk-v4.md` | W422 | execution w422 (plan) | DoD Re-walk v4 — §5 criteria 1–7 re-walked against receipts on disk (`test -f` verified); supersedes W206 walk |
| `w429-marketplace-slice.md` | W429 | execution w429 | marketplace non-stress suite + lawful status-transition idiom (read-only, no commits) |
| `w431-os13-cache-mirror.md` | W431 | execution w431 | OS-13 mechanical half: cache-clone marker mirror over ash_surface `.ggen-v2/git-packs/ash-extension` sync cache + ggen-marketplace (marker source) |
| `w433-operations-slice.md` | W433 | execution w433 | operations slice verification receipt (canonical checkout, no commit) |
| `w438-pw-final-quiet.md` | W438 | execution w438 | PW final re-witness under fleet-quiet conditions (INTERNAL_API_TOKEN set, pinned asdf) |
| `w440-cleanup-manifest.md` | W440 | execution w440 | final operator cleanup manifest — nothing deleted, fleet read-only, this file only write |
| `w444-crash-dump-classification.md` | W444 | execution w444 | erl_crash.dump classification (51,099,221 bytes, mtime Oct 6 17:55) |
| `w185-refusal-batch6-receipt.md` | W185 | execution w185 | batch6/r2rml refusal fixtures (standalone receipt) |
| `w394-admin-ingest-fix.md` | W394 | execution w394 | ash_admin :ingest regression diagnosis — W391 policy hypothesis refuted |
| `w425-ultracode-slice.md` | W425 | execution w425 | final-tree ultracode regression slice |
| `w427-stress-drift-fix.md` | W427 | execution w427 | stress-test status-drift fix (W386 typed finding) |
| `w432-telemetry-slice.md` | W432 | execution w432 | final-tree telemetry slice (v26.10.6 convergence) |
| `w434-witness-slice.md` | W434 | execution w434 | witness slice receipt (v26.10.6) |
| `w435-chicago-slice.md` | W435 | execution w435 | final-tree chicago slice receipt |
| `w436-mixtasks-slice.md` | W436 | execution w436 | final-tree mix-tasks test slice receipt |
| `w437-fabric-slice.md` | W437 | execution w437 | fabric slice — final-tree verification receipt |
| `w442-sjira-slice.md` | W442 | execution w442 | final-tree sjira dir slice witness (v26.10.6 convergence) |
| `w443-receipt-slice.md` | W443 | execution w443 | receipt dir slice at final tree (incl. W369's converted r_projection) |
| `w445-prometheus-rewitness.md` | W445 | execution w445 | Prometheus controller re-witness (W416 F1) |
| `w446-vault-strict-recheck.md` | W446 | execution w446 | vault.ex strict-compile recheck post-OS-17 |
| `w447-semantics-slice.md` | W447 | execution w447 | final-tree semantics slice receipt |
| `w449-ash-admin-independent.md` | W449 | execution w449 | independent verification of W394's CapabilityLivenessReceipt :ingest fix |
| `w452-pw-post-fix.md` | W452 | execution w452 | PW post-fix full tokened suite (v26.10.6) |
| `w455-library-slice.md` | W455 | execution w455 | library slice receipt (v26.10.6) |
| `w462-pplan-pin-staging.md` | W462 | execution w462 | ash_pplan pin advance staging (P0-3 close-out) |
| `w463-remaining-dirs-slice.md` | W463 | execution w463 | remaining test/xaas dirs slice |
| `w464-commit-manifest-v3.md` | W464 | execution w464 | commit manifest v3 (supersedes W153 v2 / W214 / W399 amendments) |
| `w466-os-register-check.md` | W466 | execution w466 | OS register internal-consistency check (§4 of `_CLOSURE_PLAN.md`) |
| `w467-release-audit-pin.md` | W467 | execution w467 | release-audit pin drift receipt |
| `w316-tokened-full-suite.md` | W316b | execution w316 | tokened full-suite (relaunch of W316) @ d1db2b03 |
| `w453-conference-slice.md` | W453 | execution w453 | conference slice at final tree (canonical checkout, no commits) |
| `w454-a2a-slice.md` | W454 | execution w454 | a2a slice at final tree (canonical checkout, no commits) |
| `w456-bridges-slice.md` | W456 | execution w456 | final-tree bridges slice (lib/xaas/bridges incl. pplan vs test/xaas/bridges + chicago/bridges) |
| `w457-autofde-slice.md` | W457 | execution w457 | autofde dir slice at final tree |
| `w459-live-slice.md` | W459 | execution w459 | final-tree LiveView dir slice (test/xaas_web/live/, lane build root `_build-laneW459`) |
| `w460-admin-spec-settle.md` | W460 | execution w460 | admin e2e specs settle-wait for New-form hydration race (e2e .cjs writes only, no lib/ edits) |
| `w470-load-admissibility.md` | W470 | execution w470 | load-admissibility adjudication of v26.10.6 receipts (W461 rule: receipts minted at load >50 inadmissible for contention-sensitive classes) |
| `w471-pw-remint.md` | W471 | execution w471 | PW suite re-mint #1 (queued per w470 admissibility; load gate 9.30 < 10 open) |
| `w472-web-slice-remint.md` | W472 | execution w472 | web+accounts slice re-mint (w470 item #2; load 9.11 admissible) |
| `w473b-quiescent-suite.md` | W473b | execution w473b | quiescent full-suite clean run (DoD 1 closure) — verdict GATED(load) |
| `w474-annex-iv-rerun.md` | W474 | execution w474 | Annex-IV full-app gate rerun (W504 BLOCKED resolution; quiescent_stop.ex compile fix + dataset_admission repair) |
| `w500-art5-admission.md` | W500 | execution w500 | Art. 5(1)(a)–(h) constructive-nullification admission profile (eu_ai_act_admission.ex + test) |
| `w501-art9-reachability.md` | W501 | execution w501 | Art. 9 inverse-reachability safe-set compilation, Theorem 3.1 (subject /Users/sac/ferroplan, target /tmp/w501-target) |
| `w502-art10-dataset-gate.md` | W502 | execution w502 | Art. 10 dataset admission gate (Theorem 3.2) |
| `w503-art12-audit-chain.md` | W503 | execution w503 | Art. 12 audit chain (Def 4.2 + Thm 4.1), lane build root `_build-laneW503` |
| `w504-art11-annex-iv.md` | W504 | execution w504 | Art. 11 Annex-IV functorial technical-documentation generator (BLOCKED, resolved by W474) |
| `w505-art13-shapley.md` | W505 | execution w505 | Art. 13 exact Shapley attribution over the discrete admission lattice |
| `w506-art86-counterfactual.md` | W506 | execution w506 | Art. 86 counterfactual explanation (Theorem 7.1; counterfactual.ex + test) |
| `w507-art14-estop.md` | W507 | execution w507 | Art. 14(4)(e) emergency-stop attractor (Theorem 5.2) |
| `w508-art15-margin.md` | W508 | execution w508 | Art. 15 robust margin gate (Theorem 5.3, dissertation Ch5) |
| `w509-wasi-gate.md` | W509 | execution w509 | eyerun_wasi WebAssembly SHACL admission gate (Thm 5.4; crate receipt-only, not committed) |
| `w510-mldsa-signing.md` | W510 | execution w510 | ML-DSA-65 runtime-signed receipt witness (Ch6, closes w405 no-witnessed-signature gap) |
| `w511-art72-conformance.md` | W511 | execution w511 | Art. 72 token-replay conformance (Def 7.2; subject /Users/sac/beam4pm) |
| `w512-gpai-decoupling.md` | W512 | execution w512 | GPAI authority decoupling property pins (Ch6 Thm 6.1) |
| `w513-conformance-pack.md` | W513 | execution w513 | EU AI Act conformance pack — doc-level export (runtime half of OS-14) |
| `w514-jcs.md` | W514 | execution w514 | RFC 8785 JCS canonicalization (substrate lane) |
| `w521-art5-integration.md` | W521 | execution w521 | Art. 5 admission live-surface integration |
| `w522-title-ii.md` | W522 | execution w522 | Title II (Art. 5) Chicago-test suite (test/eu_ai_act/title_ii_test.exs) |
| `w523-title-iii.md` | W523 | execution w523 | Title III generator (Arts 6–49, 391 corpus lines) |
| `w524-title-iv-v.md` | W524 | execution w524 | Title IV+V generator (Arts 50–55) |
| `w524b-audit-chain-integration.md` | W524b | execution w524b | audit-chain integration (Thm 4.1 vs the real actuation receipt stream; no lib edits) |
| `w525-title-vi-xiii.md` | W525 | execution w525 | Titles VI–XIII generator (Arts 57–113) |
| `w525b-title-i.md` | W525b | execution w525b | Title I generator (Arts 1–4) |
| `w525d-map-update-sweep.md` | W525d | execution w525d | `Map.update/4` absent-key deviation sweep over otp-29 repos (beam4pm, ash_a2a, ash_pplan, ex4pm) |
| `w526-euaia-suite-wiring.md` | W526 | execution w526 | EU AI Act suite wiring |
| `w526b-euaia-aggregation.md` | W526b | execution w526b | EU AI Act aggregation runner (terminal aggregation, private build root) |
| `w527-corpus-coverage-audit.md` | W527 | execution w527 | EU-AI-Act corpus coverage audit (docs/eu_ai_act/corpus.json, 1068 line_ids verified unique) |
| `w531-title-ii-corpus-loop.md` | W531 | execution w531 | Title II corpus-loop receipt |
| `w532-art9-13-14-gaps.md` | W532 | execution w532 | Art 9/13/14 OPEN_GAP reclassification (first OPEN_GAP→EVIDENCED lane) |
| `w533-art50-2-marking.md` | W533 | execution w533 | Art. 50(2) synthetic-content marking (closes w524's single OPEN_GAP) |
| `w534-title-iii-restructure.md` | W534 | execution w534 | Title III suite restructure (W525 two-module pattern) |
| `w535-title-iii-remaining-gaps.md` | W535 | execution w535 | Title III remaining OPEN_GAP reclassification (Arts 8, 10, 11, 15, 26, 27) |
| `w536-art15-3-metrics.md` | W536 | execution w536 | Art. 15(3) declared-metrics surface |
| `w537-art26-27-governance.md` | W537 | execution w537 | Art. 26.6 retention / Art. 26.7 worker notification / Art. 27 FRIA |
| `w538-art73-incident-report.md` | W538 | execution w538 | Art. 73 serious-incident reporting surface |
| `w539-art14-4b-bias-countermeasure.md` | W539 | execution w539 | Art. 14.4.b automation-bias countermeasure (mandatory causal-anatomy presentation) |
| `w540-art15-5-lifecycle.md` | W540 | execution w540 | Art. 15(5) vulnerability detect/respond/resolve lifecycle |
| `w541-master-equation.md` | W541 | execution w541 | Master Equation composition court (dissertation Ch. 9) |
| `w543-euaia-aggregation-2.md` | W543 | execution w543 | EU-AI-Act wave fresh suite aggregation (supersedes W526b) |
| `w545-ocel-fitness.md` | W545 | execution w545 | OCEL fitness integration witness (Art. 72 / w511 over the real xaas OCEL stream) |
| `w546-os18-fix.md` | W546 | execution w546 | OS-18: `checkpoint_external/2` tautology fix + witness flip + corpus rerun (placeholder filled) |
| `w547-gap-flips.md` | W547 | execution w547 | consolidation flip pass: OPEN_GAP → EVIDENCED / NOT_APPLICABLE |
| `w550-counterfactual-harness.md` | W550 | execution w550 | counterfactual test harness (EU AI Act wave) |
| `w551-counterfactual-kill-ledger.md` | W551 | execution w551 | counterfactual harness mutation ledger (dissertation §4, KillScore) |
| `w600-airo-vendor.md` | W600 | execution w600 | AIRO vendor receipt (AIRo wiring wave) |
| `w600-os19-fix.md` | W600 | execution w600 (OS-19) | release_audit stale-pin fix |
| `w601-airo-mapping.md` | W601 | execution w601 | AIRo risk mapping lane receipt |
| `w601-beam4pm-map-update.md` | W601 | execution w601 (OS-20) | beam4pm `Map.update/4` ABSENT-KEY-RELIANT patch (OS-20) |
| `w602-airo-marketplace.md` | W602 | execution w602 | AIRo vendored into ggen-marketplace active pack |
| `w602-ash-a2a-map-update.md` | W602 | execution w602 (OS-20) | ash_a2a `Map.update/4` dual-safe sweep (OS-20) |
| `w603-ash-pplan-map-update.md` | W603 | execution w603 (OS-20) | ash_pplan `Map.update/4` absent-key-reliant sweep (OS-20) |
| `w603-gymact-airo.md` | W603 | execution w603 | gymact AIRo risk description |
| `w604-autofde-airo.md` | W604 | execution w604 | autofde-lab AIRo risk description |
| `w604-ex4pm-map-update.md` | W604 | execution w604 (OS-20) | ex4pm `Map.update/4` absent-key-reliant sweep (OS-20 / ex4pm leg) |
| `w605-ash-a2a-airo.md` | W605 | execution w605 | ash_a2a AIRo risk description |
| `w605-euaia-aggregation-3.md` | W605 | execution w605 | EU-AI-Act post-flip aggregation (final gate + census) |
| `w606-corpus-coverage-audit-2.md` | W606 | execution w606 | EU AI Act corpus coverage audit rerun 2 (supersedes W527 INCOMPLETE) |
| `w607-349-41-closures.md` | W607 | execution w607 | Title I 3.49-family + 4.1 closures |
| `w608-art56-boundary.md` | W608 | execution w608 | Art. 56 boundary closure (Title IV+V corpus range 28..55 → 28..56) |
| `w609-oracle-site.md` | W609 | execution w609 | reference_oracle Map.update site fix (OS-20 follow-up) |
| `w610-ash-pplan-suite-capture.md` | W610 | execution w610 | ash_pplan full-suite receipt-grade capture |
| `w611-corpus-coverage-final.md` | W611 | execution w611 | EU AI Act corpus coverage FINAL audit (post-W608 + W607) |
| `w614-ggen-airo.md` | W614 | execution w614 | ggen AIRo risk description (ggen leg) |
| `w615-wasm4pm-zcode-airo.md` | W615 | execution w615 | wasm4pm + zcode-cli AIRo risk descriptions |
| `w616-deepening.md` | W616 | execution w616 | corpus evidenced-line deepening receipt |
| `w617-property-deepening.md` | W617 | execution w617 | property/fuzz deepening: AuditChain + JCS |
| `w618-ggen-igniter-airo.md` | W618 | execution w618 | ggen_igniter AIRo risk description |
| `w619-deepening-iv-xiii.md` | W619 | execution w619 | evidenced-line deepening, Titles IV+V and VI–XIII |
| `w619-ggen-igniter-asdf-rerun.md` | W619 | execution w619 | ggen_igniter asdf-shim rerun of W618's court |
| `w620-os14-export-endpoint.md` | W620 | execution w620 (OS-14) | runtime export API (GAP(NO_RUNTIME_EXPORT_API) closure) |
| `w620-os20-consolidation.md` | W620 | execution w620 (OS-20) | OS-20 consolidation receipt (v26.10.6) |
| `w621-admission-fuzz.md` | W621 | execution w621 | admission-gate totality fuzz |
| `w621b-airo-pin.md` | W621b | execution w621b | AIRo vendored-vocabulary pin |
| `w622-euaia-aggregation-4.md` | W622 | execution w622 | EU-AI-Act wave aggregation receipt (fresh, current tree) |
| `w623-title-iii-deepening.md` | W623 | execution w623 | Title III evidenced-line deepening |
| `w624-counterfactual-extension.md` | W624 | execution w624 | counterfactual harness extension |
| `w624b-harness-repair.md` | W624b | execution w624b | counterfactual harness repair |
| `w625-authority-channel.md` | W625 | execution w625 | authority-channel registry (73.x / 3.49 / 27.1.f seam) |
| `w625b-master-equation-check.md` | W625b | execution w625b | Master Equation suite drift check/repair |
| `w625c-art73-flips.md` | W625c | execution w625c | Titles VI–XIII Art 73-family flips |
| `w625d-ash-r2rml-airo.md` | W625d | execution w625d | ash_r2rml AIRo risk description |
| `w626-semantics-convergence.md` | W626 | execution w626 | semantics-dir convergence receipt |
| `w626b-euaia-aggregation-5.md` | W626b | execution w626b | EU-AI-Act fresh aggregation receipt (post W547/W607 flip waves + W531 Title II loop) |
| `w626c-deepening-iv-xiii.md` | W626c | execution w626c | Titles IV+V and VI–XIII evidenced-line deepening |
| `w627-art73-flips.md` | W627 | execution w627 | Art 73-family flips (Titles VI–XIII) |
| `w628-master-equation-soak.md` | W628 | execution w628 | Master Equation determinism soak |
| `w629-euaia-readme.md` | W629 | execution w629 | EU AI Act suite README receipt |
| `w630-totality-fix.md` | W630 | execution w630 (OS-21) | OS-21: admission-gate totality fix (4 w621 escapes) |
| `w631-rpc-alignment-fix.md` | W631 | execution w631 | check_rpc_alignment typed refusal (OS-19 follow-up b) |
| `w632-kanban-web-drift.md` | W632 | execution w632 | kanban_web drift diagnosis |
| `w633-gettext-sweep.md` | W633 | execution w633 | gettext stale doc-comment sweep |
| `w634-art14a-counterfactual.md` | W634 | execution w634 | Art. 14(4)(a) explanation-suppression counterfactual row |
| `w634-beam4pm-airo.md` | W634 | execution w634 | beam4pm AIRo risk description |
| `w635-ash-pplan-airo.md` | W635 | execution w635 | ash_pplan AIRo risk description |
| `w635-euaia-aggregation-6.md` | W635 | execution w635 | EU-AI-Act wave aggregation rerun (6th) |
| `w635b-authority-witness.md` | W635b | execution w635b | 73.6.s2 internal-escalation end-to-end witness |
| `w636-rpc-repoint.md` | W636 | execution w636 | rpc-check repoint (W632 disposition closure) |
| `w637-affidavit-surface-airo.md` | W637 | execution w637 | ash_affidavit + ash_surface AIRo risk descriptions |
| `w637b-flake-fix.md` | W637b | execution w637b | counterfactual_test.exs seed-dependent flake fix |
| `w638-ferroplan-airo.md` | W638 | execution w638 | ferroplan AIRo risk description |
| `w639-airo-ledger.md` | W639 | execution w639 | AIRo wiring ledger consolidation |
| `w645-euaia-aggregation-7.md` | W645 | execution w645 | EU AI Act aggregation rerun at the fully-deepened tree |
| `w645b-ex4pm-airo.md` | W645b | execution w645b | ex4pm AIRo risk description |
| `w646-readme-refresh.md` | W646 | execution w646 | corpus-README falsifier refresh |
| `w647-semantics-slice2.md` | W647 | execution w647 | semantics dir slice-2 convergence witness |
| `w648-art74-86-classify.md` | W648 | execution w648 | Titles VI–XIII classification flip: Art 74.12/74.13.a/74.13.b + 86.2/86.3 |
| `w648b-literacy-fria.md` | W648b | execution w648b | Art. 4.1 AI-literacy + Art. 27.1.b/e/f FRIA fields |
| `w649-§5-refresh2.md` | W649 | execution w649 | §5 refresh-2 (closure plan DoD table) |
| `w649b-art8-1-flip.md` | W649b | execution w649b | Art. 8.1 umbrella flip: OPEN_GAP → EVIDENCED |
| `w650-ledger-terminal2.md` | W650 | execution w650 | terminal-2 ledger update (post-deepening/flips) |
| `w651-readme-refresh.md` | W651 | execution w651 | EU-AI-Act README census refresh |
| `w652-551d-repair.md` | W652 | execution w652 | 55.1.d repair receipt |
| `w654-env-fix.md` | W654 | execution w654 | application-env pollution flake fix (counterfactual Art 11 test) |
| `w655-title-ii-dedupe.md` | W655 | execution w655 | Title II dedupe consolidation |
| `w656-vkg-insource-doc.md` | W656 | execution w656 | vkg.ex:52 dead-clause in-source documentation |
| `w657-euaia-family.md` | W657 | execution w657 | EUAIA family clauses in `risk_concept_for/1` |
| `w657-os20-refresh.md` | W657 | execution w657 (OS-20) | OS-20 consolidation refresh (v26.10.6) |
| `w658-airo-mapping-env-fix.md` | W658 | execution w658 | airo_risk_mapping_test environment-defect fix |
| `w658-beam4pm-admission.md` | W658 | execution w658 | beam4pm HandAuthoredSource admission for the W601 test |
| `w659-xaas-dual-safe.md` | W659 | execution w659 | xaas self-patch: dual-safe Map.update/4 remediation |
| `w659b-euaia-expectation-fix.md` | W659b | execution w659b | EUAIA family test expectation fix |
| `w660-grounding-refresh.md` | W660 | execution w660 | airo_grounding refresh (flip the pinned TYPED GAP) |
| `w661-grounding-rewitness.md` | W661 | execution w661 | grounding re-witness (EUAIA merge verification) |
| `w700-ggen-gaps.md` | W700 | execution w700 | ggen gap audit → xaas fill |
| `w701-ash-a2a-gaps.md` | W701 | execution w701 | ash_a2a→xaas legacy_compat config gaps (cross-project gap wave) |
| `w702-gymact-gaps.md` | W702 | execution w702 | gymact→xaas gap wave receipt |
| `w703-autofde-gaps.md` | W703 | execution w703 | autofde-lab → xaas gap wave |
| `w704-zcode-gaps.md` | W704 | execution w704 | zcode-cli → xaas gap wave receipt |
| `w705-wasm4pm-ex4pm-gaps.md` | W705 | execution w705 | wasm4pm/ex4pm cross-project gap audit and fill |
| `w706-trio-gaps.md` | W706 | execution w706 | trio gap fill (ash_pplan + ash_r2rml + ash_affidavit → xaas) |
| `w398-refusal-capstone-final.md` | W398b | execution w398b | Refusal Capstone Corpus receipt (final adjudication) |
| `w291-ash-pplan-verdict.md` | W291 | execution w291 | ash_pplan patch landed, verdict receipt @ 414a393 |

## Totals

| group | count |
|---|---|
| Definitions (_LANES, _FRONTIER, _WIRING_MATRIX, _CLOSURE_RECEIPT) | 4 |
| Fleet audits r1–r11 | 11 |
| Vectors 1–6 (incl. both vector3 files) | 7 |
| X-lanes x1–x8 (incl. x1b) | 9 |
| Execution lanes w6–w706 | 410 |
| **Total receipt rows** | **441** |

(441 indexed rows cover all 437 non-underscore receipt `.md` files + 4 definition files (`_LANES.md`, `_FRONTIER.md`, `_WIRING_MATRIX.md`, `_CLOSURE_RECEIPT.md`); `_INDEX.md` itself is not indexed. Verified set-equal by W659d, 2026-10-07.)
