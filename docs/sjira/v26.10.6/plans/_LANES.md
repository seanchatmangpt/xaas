# v26.10.6 fleet convergence fan-out (relabeled) — lane map (2026-10-06)

Mission: every fleet repo wired through `~/xaas` & `~/ash_surface`, validated against
Playwright (E2E surface validation), v26.10.5 feature complete.

Integration base: `feat/playwright-surface` @ `d1db2b03` (xaas);
`feat/v26.10.5-release-cut` @ `000bffb8` (ggen).

Lane partition = disjoint file ownership. Shared seams (mix.exs, config/, router.ex,
package.json, playwright.config.*, ~/ash_surface/lib top-level seams) are edited ONLY by
the coordinator from lane-submitted lines. Lanes never run git commands; coordinator owns
git, seams, integration, PRs.

| lane | agent | owns (files) | deliverable |
|---|---|---|---|
| R1 | ggen audit | `~/ggen/**` | plan: ggen→xaas/ash_surface wiring gaps vs v26.10.5 |
| R2 | ggen-marketplace audit | `~/ggen-marketplace/**` | plan: pack surface + consumer wiring plan |
| R3 | ggen_igniter audit | `~/ggen_igniter/**` | plan: manufacture profile state vs v26.10.5 |
| R4 | ash_a2a audit | `~/ash_a2a/**` | plan: a2a surface wiring + validation path |
| R5 | ash_pplan audit | `~/ash_pplan/**` | plan: pplan durability wiring |
| R6 | ferroplan audit | `~/ferroplan/**` | plan: planner wiring (note: 4 dirty files — inventory, don't touch) |
| R7 | zcode-cli audit | `~/zcode-cli/**` | plan: CLI surface wiring (18 dirty files — inventory only) |
| R8 | gymact audit | `~/gymact/**` | plan: gym actuation wiring |
| R9 | beam4pm audit | `~/beam4pm/**` | plan: 2462 dirty files → classify+propose split commits plan |
| R10 | wasm4pm audit | `<repo>/**` | plan: CI/fmt/tsc state + wiring |
| R11 | autofde-lab audit | `~/autofde-lab/**` | plan: doctrine-lab wiring |
| X1 | xaas playwright inventory | `docs/sjira/v26.10.5/plans/x1*.md` only | full Playwright surface inventory + spec gap plan |
| X2 | ash_surface surface audit | `docs/sjira/v26.10.5/plans/x2*.md` only | ash_surface capability surface vs wiring needs |
| X3 | xaas web surface audit | `docs/sjira/v26.10.5/plans/x3*.md` only | LiveView/HTTP surface inventory + playwright-ability |
| X4 | deps/version seam audit | `docs/sjira/v26.10.5/plans/x4*.md` only | version pins across repos → v26.10.5 alignment plan |
| X5 | CI audit | `docs/sjira/v26.10.5/plans/x5*.md` only | CI status across fleet + wiring gates |
| X6 | milestone scaffold | `docs/sjira/v26.10.5/{_FRONTIER.md,plans/x6*.md}` only | frontier ledger + acceptance definition |
| X7 | red team | nothing (read-only) | risk register `plans/x7-risk-register.md` (may write only that file) |

## Final roster

Integration lane W181, 2026-10-06. Every lane actually executed, keyed to its receipt file
in this directory (receipt files on disk supersede the partial `_INDEX.md` execution table —
15 receipt files there have no index row). Standing per each receipt's own header.

### Fleet audits r1–r11 (11/11 executed)

| lane | receipt | outcome |
|---|---|---|
| R1 | r1-ggen.md | ALIVE (audit) — ggen @ 000bffb8, fresh convergence evidence this session |
| R2 | r2-marketplace.md | DEAD — killed early by operator; partial receipt on file (93895f808, pin drift quantified) |
| R3 | r3-igniter.md | PARTIAL_ALIVE — ash-manufacture-pack fixture-only; UNSUPPORTED hex consumers |
| R4 | r4-a2a.md | ALIVE (audit) — TCK 235/30/0 = 79.0% + wiring plan |
| R5 | r5-pplan.md | ALIVE (audit) — 26.10.3, 1 dirty docs file inventoried |
| R6 | r6-ferroplan.md | ALIVE (audit) — dirty files are ggen receipt churn only |
| R7 | r7-zcode-cli.md | ALIVE (audit) — 18 dirty paths; two-way xaas coupling documented |
| R8 | r8-gymact.md | ALIVE (audit) — actuation HTTP surface real |
| R9 | r9-beam4pm.md | ALIVE (audit) — 2,462 dirty files classified; OTP-29 move documented |
| R10 | r10-wasm4pm.md | DEAD — killed early by operator; partial receipt on file (branch merged as PR #659 @ a7352d818) |
| R11 | r11-autofde-lab.md | ALIVE — repo head, xaas read path, StatusLive surface all ALIVE |

### Vectors 1–6 (7 receipt files / 6 lanes, all executed)

| lane | receipt | outcome |
|---|---|---|
| V1 | vector1-fenced-gates.md | ALIVE (audit) — 103 forbid-floors deny-by-default; TODO(ash_surface) fence flagged stale |
| V2 | vector2-refusal-coverage.md | PARTIAL_ALIVE — xaas has 50 REFUSED_* variants with zero test coverage |
| V3 | vector3-closure-receipt.md | ALIVE — one-command closure feasible; host oracle tools all PRESENT |
| V3 | vector3-ignored-suites.md | ALIVE (audit) — 9 excluded tag classes; per-row un-ignore requirements |
| V4 | vector4-gen-parity.md | PARTIAL_ALIVE — castle.ex injection drift YES; no CI parity gate |
| V5 | vector5-limits-lints.md | ALIVE — strict-flag compile VERIFIED GREEN both repos |
| V6 | vector6-docs-abi.md | ALIVE — conformance MANIFEST re-hashed, NO DRIFT (11/11) |

### X-lanes (9/9 executed)

| lane | receipt | outcome |
|---|---|---|
| X1 | x1-playwright-inventory.md | ALIVE (plan) — harness/env contract + per-spec gap plan |
| X1b | x1b-playwright-runner.md | ALIVE — playwright 1.63.0 exact-match; 23 tests / 5 healthy files |
| X2 | x2-ash-surface.md | ALIVE (audit) — capability surface inventory, pipeline tiered |
| X3 | x3-xaas-web.md | ALIVE (audit) — LiveView inventory with routes + coverage |
| X4 | x4-version-alignment.md | ALIVE (audit) — 13-repo version alignment table |
| X5 | x5-ci.md | ALIVE (audit) — CI inventory + wiring-gate plan |
| X6 | x6-notes.md | ALIVE — _FRONTIER.md scaffolded, no git mutations |
| X7 | x7-risk-register.md | ALIVE — S0 risk identified; acceptance redefined per repo class |
| X8 | x8-ash-surface-gen.md | PARTIAL_ALIVE — full-app generation works at EA35, artifacts verified |

### Execution waves w30–w181 (56 receipt files, all executed)

| lane | receipt | outcome |
|---|---|---|
| W30 | w30-playwright-baseline.md | BLOCKED(BUILD_BROKEN) — 0 specs; dev tree did not compile |
| W35 | w35-autofde-oracle-gate.md | ALIVE — oracle gate skip condition read; no edits |
| W40 | w40-zcode-release-workflow.md | BLOCKED-typed — prepare-release failure diagnosed; fix needs release decision |
| W45 | w45-ferroplan-wasm-pin.md | ALIVE — wasm built + staged-ready at pin location |
| W46 | w46-zcode-stream-tests.md | ALIVE — correct unit entrypoint identified |
| W51 | w51-integration-verify.md | BLOCKED — Gate 1 compile TokenMissingError; priv/ eacces disclosed |
| W52 | w52-beam4pm-qualification.md | PARTIAL_ALIVE — compile exit 0; test failures root-caused to missing wasm |
| W58 | w58-zcode-deps.md | ALIVE — deps installed, closing W46's 42-of-44 failure cluster |
| W61 | w61-castle-bin-gate.md | PARTIAL_ALIVE — CASTLE_BIN gate 2/3; 1 pre-existing source defect |
| W68 | w68-full-suite.md | BLOCKED — :ash_affidavit dep compile failure |
| W68b | w68b-full-suite.md | PARTIAL_ALIVE — 3145/3201; 56 failures classified (BUILD_GREEN / TEST_PARTIAL) |
| W69 | w69-gates-rerun.md | ALIVE — rerun-only re-execution of W51 gates; no fixes |
| W70 | w70-playwright-full.md | PARTIAL_ALIVE — webServer spawn failed (xattr); suite ran vs manual boot |
| W74 | w74-rust4pm-wasm.md | ALIVE — rust4pm WASM built (exit 0), closing W52 residual |
| W75 | w75-ex4pm-baseline.md | ALIVE — ex4pm OTP-29 baseline @ 9f7aecd, verbatim counts |
| W76 | w76-ash-r2rml-baseline.md | ALIVE — 998 tests / 0 failures / 9 skipped |
| W77 | w77-ash-a2a-baseline.md | ALIVE — 3707/3708 (1 load-dependent timeout flake) |
| W78 | w78-autofde-baseline.md | PARTIAL_ALIVE — `just test` baseline; heavy suites not run (disclosed) |
| W79 | w79-gymact-dcm.md | PARTIAL_ALIVE — DCM-001..017 STRUCTURAL; DCM-018 crown UNKNOWN |
| W80 | w80-pack-repin-diff.md | ALIVE — re-pin diff baa5f117 → 3ddbfeb7 (31 commits, read-only) |
| W81 | w81-ggen-cargo-check.md | ALIVE — cargo check --workspace exit 0, Cargo.lock settled |
| W82 | w82-oracle-rerun.md | ALIVE — vector-3 oracle rerun, receipt-only |
| W85 | w85-mix-generator-parity.md | PARTIAL_ALIVE — zcode byte-identical; 3 formatting drifts; 1 permanent-UNKNOWN |
| W87 | w87-ci-validation.md | ALIVE — 21/21 workflow YAML valid + mock gate clean |
| W90 | w90-repin-verify.md | BLOCKED — ash-extension sync refuses at tip 3ddbfeb7 |
| W91 | w91-permission-sweep.md | ALIVE — 17-repo chmod sweep; damaged repos repaired, no content changes |
| W94 | w94-wasm4pm-flake.md | ALIVE — CI flake fixed (float-boundary epsilon in the test itself) |
| W102 | w102-ash-surface-full-suite.md | ALIVE — tracked tests clean; JS surface 367/367 |
| W103 | w103-prod-compile.md | ALIVE — MIX_ENV=prod compile --force under pinned toolchain; log retained |
| W105 | w105-marketplace-baseline.md | ALIVE — gates ALIVE; 1956 passed |
| W107 | w107-schema-drift.md | PARTIAL_ALIVE — validator oracle 52/56; residual 4 BLOCKED(machinery_absent) |
| W108 | w108-sibling-build.md | ALIVE — ggen_igniter rebuild: 1555 green, credo clean |
| W110 | w110-autofde-import.md | ALIVE — ImportError eliminated, 34+ → 0 |
| W111 | w111-pw-interim.md | PARTIAL_ALIVE — 6 repaired spec classes vs live server; exit 1, counts recorded |
| W112 | w112-witness-nextread-pw.md | PARTIAL_ALIVE — witness 2/1s; next-read 5/1 (real checkout-button failure) |
| W113 | w113-a2a-pw.md | BLOCKED-typed — token branch 11/7 (pending migrations); tokenless 3/15 = honest 503 floor |
| W114 | w114-commit-plan.md | PLAN-ONLY — integration commit plan, no git mutations |
| W118 | w118-pw-final.md | PARTIAL_ALIVE — full suite 62 passed / 32 failed / 3 skipped |
| W120 | w120-web-suite.md | ALIVE — web layer 347 passed / 1 excluded (verbatim) |
| W122 | w122-igniter-final.md | PARTIAL_ALIVE — 1555/1 failure (W38 anchor), no fix per lane instructions |
| W126 | w126-pack-gate-fix.md | ALIVE — 5 pack repairs verified, verdict COMMIT-READY |
| W129 | w129-gymact-crown.md | ALIVE — full DCM flow witnessed; CROWN_CANNOT_BE_PREMARKED_ALIVE enforced |
| W131 | w131-operations-suite.md | ALIVE — 103 passed / 0 failed / 20 excluded on d1db2b03 |
| W132 | w132-verify-rehearsal.md | BLOCKED — compile OK; stages 2+ blocked on ash_surface dep; tests NOT RUN |
| W135 | w135-witness-pw.md | BLOCKED — webServer boot failed (:ash_surface dep compile); 0 tests |
| W136 | w136-migration-check.md | ALIVE — repair migration safe on fresh DB (8/8 tests) |
| W139 | w139-e4-adjudication.md | PARTIAL_ALIVE — sjira layers 103/107; 4 failures classified BLOCKED (OS-9 law evolution) |
| W146 | w146-chicago-suite.md | BLOCKED(BUILD_BROKEN) — compile exit 1, 0 tests |
| W148 | w148-bridges-ultracode.md | BLOCKED(BUILD_BROKEN) — ash_a2a 26.10.4 dep compile failure, pre-existing |
| W149 | w149-validator-health.md | ALIVE — no latent NameError in validate_receipt.py |
| W151 | w151-dev-migrate.md | ALIVE — dev DB converged (`Migrations already up` x2) |
| W153 | w153-commit-plan-v2.md | PLAN-ONLY — W114 refresh with fresh inventory, no git |
| W165 | w165-wasm4pm-bumps.md | ALIVE — wasm4pm version 26.9.28 → 26.10.6 (14 files) |
| W167 | w167-pg-saturation.md | ALIVE — pool sizing fixed; chicago 150/0; server 108/200 connections |
| W168 | w168-specimen-disposition.md | PARTIAL_ALIVE — 24 untracked specimens parked, none deleted (non-ignored) |
| W173 | w173-boot-chain.md | PARTIAL_ALIVE — boot chain healthy; gate run 11 failed / 3 passed |

### Dead lanes

| lane | status |
|---|---|
| R2 | killed early by operator; partial receipt `r2-marketplace.md` on file |
| R10 | killed early by operator; partial receipt `r10-wasm4pm.md` on file (branch merged as PR #659) |
| W20 | no receipt on file, absent from all lane records — no evidence it is still running; treat as never-materialized |

### Totals per group

| group | lanes executed | standing split |
|---|---|---|
| Fleet audits r1–r11 | 11 | 8 ALIVE, 1 PARTIAL_ALIVE, 2 DEAD (operator kill) |
| Vectors 1–6 | 6 (7 receipt files) | 5 ALIVE, 2 PARTIAL_ALIVE |
| X-lanes x1–x8 | 9 (incl. x1b) | 8 ALIVE, 1 PARTIAL_ALIVE |
| Execution waves w30–w181 | 56 receipt files | 29 ALIVE, 15 PARTIAL_ALIVE, 10 BLOCKED-typed, 2 PLAN-ONLY |
| **Total receipt files on disk** | **83** | |
