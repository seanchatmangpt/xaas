# W883 — Fleet Integration Manifest (v26.10.6 wave outputs)

**Standing**: MANIFEST (findings only — no commits, no sync runs performed by this lane).
**Date**: 2026-10-07. **Lane**: W883.
**Identity**: authored on xaas `feat/playwright-surface` @ `a0723bf6`.
**Falsifier**: every `git status --porcelain` line below is real observed output on the named
canonical checkout at the named HEAD; the manifest is REFUTED if any scoped path is absent on
disk or any stated branch/HEAD mismatches `git -C <repo> status` / `rev-parse`.

## Execution order (why this order)

1. **ggen-marketplace first** — xaas's `ggen sync` consumes its pack commit; the marketplace pack
   surface is upstream authority for generated projections.
2. **ggen** — its `scripts/check_airo.sh` + pin script are consumed by ledger verification flows.
3. **beam4pm** — the vendored submodule commit must precede the beam4pm gitlink bump.
4. **Independent pin-test repos, any order / concurrent**: ash_surface, gymact, autofde-lab,
   wasm4pm, zcode-cli, ex4pm, ash_pplan.
5. **ferroplan** — TTL + untracked script; the ExUnit pin itself lives in xaas (W693 routing).
6. **xaas last** — after all fleet pins are committed, run the fleet-pin suite + `ggen sync`
   (out of this lane's scope).

## Per-repo manifest (one commit per repo)

Scoping rule: only the named wave's files enter the proposed commit; other dirty state is
outside-wave, disclosed but NOT committed by this wave.

### 1. ggen-marketplace — W756 (ontology edit) + W687 (pin test)

- Path/branch/HEAD: `/Users/sac/ggen-marketplace`, `feat/aaif-gcp-roadmap-v26.10.5` @ `4bb5fbaff4ac8f1ace120e356d06d1b3ebe1cf86`
- `git status --porcelain` (scoped, real output):
  ```
   M packs/xaas-castle-bridge-pack/ontology.ttl
  ?? tests/test_airo_pin_w687.py
  ```
- Owning receipts (xaas): `w756-errc-rationale-refresh.md`, `w687-ggen-marketplace-airo-pin.md`
- Proposed commit:
  ```
  fix(packs): castle-bridge ERRC rationale refresh (W756) + AIRo pin court (W687)

  castle-bridge ontology rationale literal refreshed to freshly derived counts
  (117 wrapper / 152 Ash.Resource / 19 domains); new rdflib AIRo pin court
  tests/test_airo_pin_w687.py (triple count, sha256 byte-hash, namespace sanity,
  real marketplace validate subprocess). Receipts: xaas w756 + w687.
  ```
- Operator gate: **branch is `feat/*`** — commits land on `feat/aaif-gcp-roadmap-v26.10.5`;
  merge only on explicit request. Outside-wave dirty state disclosed: CHANGELOG.md,
  marketplace.active.toml, ash-extension-pack ontology/gates/templates, `.tool-versions`.

### 2. ggen — W684 (fail-closed script) + W695 (pin)

- Path/branch/HEAD: `/Users/sac/ggen`, `feat/v26.10.5-release-cut` @ `bc4d23909dbcfd51b368f182f94655860041b04f`
- Porcelain (scoped):
  ```
   M scripts/check_airo.sh   (+7/-3, W684 fail-closed edit)
  ?? scripts/test_airo_pin.py (W695)
  ```
- Owning receipts: `w684-check-airo-fail-closed.md`, `w695-ggen-airo-pin.md`
- Proposed commit:
  ```
  fix(scripts): check_airo fail-closed exit coupling (W684) + AIRo pin test (W695)

  rdflib-parse and structural-fallback blocks now set fail=1 on error; final
  line exits 1 on FAIL (exit text and code provably coupled, +7/-3). New
  standalone pytest AIRo pin module scripts/test_airo_pin.py (rdflib parse,
  triple count, cited-path existence, vocab-term asserts). Receipts: xaas
  w684 + w695.
  ```
- Gates: none. Outside-wave dirty: `.claude-plugin/marketplace.json`, `.specify/repo-facts.ttl`,
  `Cargo.lock`, `crates/*/Cargo.toml`, `ggen.toml`.

### 3. beam4pm — W658b (admissions)

- Path/branch/HEAD: `/Users/sac/beam4pm`, `main` @ `813eb924`
- Porcelain (scoped, per W658b receipt's file list):
  ```
   M ggen.lock                              (regenerated: pack hash changed by ceiling edit)
   M ontology.ttl                           (SHA_DRIFT digest refresh + 3 new HandAuthoredSource individuals)
   M schema/beam4pm_hand_authored_source.tsv (regenerated; 102 qualification-debt rows)
   M vendor/ggen-marketplace                (gitlink — pack ceiling 99→102 edited inside submodule)
  ?? test/beam4pm_airo_description_test.exs (W634's court, admitted via W658b)
  ```
- Owning receipts: `w658-airo-mapping-env-fix.md`, `w658b-beam4pm-admissions.md`
- Proposed commits — **two-commit shape forced by the submodule**:
  1. inside `vendor/ggen-marketplace`: `chore(vendor-pack): beam4pm-process-model-pack debt ceiling 99→102 (W658b)`
  2. superproject: `chore(admission): qualify 3 hand-authored sources, ceiling 99→102, digest refresh, ggen.lock regen (W658b)` (includes gitlink bump)
- Operator gate: **vendored-pack edit lives in an uncommitted submodule gitlink** — commit the
  submodule first or the superproject gitlink dangles. Outside-wave dirty: ~30
  `lib/beam4pm_ash/resources/*_admission.ex` + `schema/beam4pm_types.schema.json` (other waves).

### 4. ash_surface — W675 (pin test)

- Path/branch/HEAD: `/Users/sac/ash_surface`, `main` @ `d55c576d1`
- Porcelain (scoped):
  ```
  ?? test/airo_surface_pin_w675_test.exs
  ```
- Owning receipt: `w675-ash-surface-airo-pin.md`
- Proposed commit:
  ```
  test: AIRo surface pin court (W675)

  ExUnit pin of the ash_surface AIRo wiring surface; typed drift failures
  naming the consuming surface. Receipt: xaas w675.
  ```
- Gates: none. Outside-wave dirty: large (conformance/, lib/, ~30 modified tests, ~40 untracked
  court tests from other lanes) — disclosed, out of scope.

### 5. gymact — W677 (pin test)

- Path/branch/HEAD: `/Users/sac/gymact`, `v26926/gymact-land-aloop-execution-kernel` @ `20b3fd7`
- Porcelain (scoped):
  ```
  ?? tests/test_airo_w677_pin.py
  ```
- Owning receipt: `w677-gymact-airo-pin.md`
- Proposed commit:
  ```
  test: AIRo wiring pin (W677)

  pytest AIRo pin over the gymact ggen/fastapi surfaces (real rdflib, no mocks).
  Receipt: xaas w677.
  ```
- Gates: none. Outside-wave dirty: CHANGELOG/README/docs/pyproject/src edits (other waves).

### 6. autofde-lab — W678 (pin test)

- Path/branch/HEAD: `/Users/sac/autofde-lab`, `feat/doctrine-lab` @ `2a3d064e`
- Porcelain (scoped):
  ```
  ?? ontology/airo_risk_description.ttl
  ?? tests/ontology/test_airo_risk_description.py
  ?? tests/ontology/test_w678_airo_pin.py
  ```
- Owning receipt: `w678-autofde-lab-airo-pin.md`
- Proposed commit:
  ```
  test: AIRo risk description + pin courts (W678)

  ontology/airo_risk_description.ttl with rdflib description and pin courts
  under tests/ontology/. Receipt: xaas w678.
  ```
- Gates: none. Outside-wave dirty: benchmark findings doc + `vendor/gyms` submodule pointers.

### 7. wasm4pm — W681 (pin test)

- Path/branch/HEAD: `/Users/sac/wasm4pm`, `fix/v26.9.30-ci-fmt-tsc` @ `32deb59f6`
- Porcelain (scoped):
  ```
  ?? tests/ontology/  (airo_risk_description.ttl, test_airo_risk_description.py, test_airo_w681_pin.py)
  ```
- Owning receipt: `w681-wasm4pm-airo-pin.md`
- Proposed commit:
  ```
  test: AIRo risk-description + pin courts under tests/ontology/ (W681)

  untracked-evidence-surface: this directory was never committed upstream
  (same class as crates/eu_gate/). Committing tests/ontology/ commits the pin
  evidence; crates/eu_gate/ stays out of this wave's commit (separate decision).
  Real rdflib courts, no mocks. Receipt: xaas w681 (+ w673 finding).
  ```
- Gates: `crates/eu_gate/` untracked (W673's finding) — deliberately excluded.

### 8. zcode-cli — W683 (pin test)

- Path/branch/HEAD: `/Users/sac/zcode-cli`, `fix/v26926-preview-publish-typed-skip` @ `eb97f76`
- Porcelain (scoped):
  ```
  ?? test/airo-wiring-w683.test.ts
  ```
- Owning receipt: `w683-zcode-cli-airo-pin.md`
- Proposed commit:
  ```
  test: AIRo wiring pin (W683)

  node:test AIRo wiring pin over the zcode surface. Receipt: xaas w683.
  ```
- Gates: none. Outside-wave dirty: docs/scripts/src/test edits + `artifacts/` untracked.

### 9. ex4pm — W680 (pin test)

- Path/branch/HEAD: `/Users/sac/ex4pm`, `main` @ `46bfcc8`
- Porcelain (scoped):
  ```
  ?? test/w680_airo_surface_pin_test.exs
  ```
- Owning receipt: `w680-ex4pm-airo-pin.md`
- Proposed commit:
  ```
  test: AIRo surface pin court (W680)

  ExUnit AIRo surface pin. Receipt: xaas w680.
  ```
- Gates: `ex4pm-26.10.1.tar` untracked build artifact — do not commit.

### 10. ash_pplan — W682 (pin test)

- Path/branch/HEAD: `/Users/sac/ash_pplan`, `fix/ggen-verify-header` @ `7eeaaa1`
- Porcelain (scoped):
  ```
  ?? test/airo_surface_pin_test.exs
  ```
- Owning receipt: `w682-ash-pplan-airo-pin.md`
- Proposed commit:
  ```
  test: AIRo surface pin court (W682)

  ExUnit AIRo pin over the ash_pplan task surface. Receipt: xaas w682.
  ```
- Gates: `docs/sjira/v26.10.6/` untracked in ash_pplan (lane receipts) — excluded from this
  wave's commit (separate decision, same class as wasm4pm `crates/eu_gate/`).

### 11. ferroplan — W693 (TTL) + W684 (script)

- Path/branch/HEAD: `/Users/sac/ferroplan`, `main` @ `c037876`
- Porcelain (scoped):
  ```
  ?? docs/airo-risk-description.ttl
  ?? scripts/check_airo.sh  (W684's fail-closed edit targets an untracked file)
  ```
- Owning receipts: `w693-ferroplan-airo-pin.md`, `w684-check-airo-fail-closed.md`
- Proposed commit:
  ```
  chore(evidence): AIRo risk-description TTL + check_airo.sh (W693/W684)

  docs/airo-risk-description.ttl (34 triples, 5,417 B) and the fail-closed
  scripts/check_airo.sh (W684's edit lives in a file never committed upstream
  — untracked-evidence-surface class, W673/W693 finding). The ExUnit pin lives
  in xaas (W693 routing decision: ferroplan is a Rust workspace, no mix).
  ```
- Gate: **must `git add` the untracked script**, or the W684 fix is lost at commit time.
  Outside-wave dirty: `.ggen-v2` receipts, `crates/ferroplan` changes, wasm registry artifact.

### 12. xaas (this repo) — W693 pin + W883 manifest

- Branch/HEAD: `feat/playwright-surface` @ `a0723bf6`
- Wave files: `test/xaas/semantics/ferroplan_airo_pin_test.exs` (W693's pin, untracked);
  `docs/sjira/v26.10.6/plans/w883-fleet-receipt-integration.md` (this manifest).
- Proposed commit (coordinator, at integration):
  `test: ferroplan AIRo pin court (W693) + fleet integration manifest (W883)`

## Totals

| metric | value |
|---|---|
| repos with wave outputs | 12 (11 fleet + xaas) |
| scoped file paths | 18 fleet + 2 xaas |
| receipts referenced | w658, w658b, w675, w677, w678, w680, w681, w682, w683, w684, w687, w693, w695, w756 |
| commits proposed | 13 (12 one-per-repo + 1 vendored submodule commit inside beam4pm) |
| operator gates | ggen-marketplace `feat/*` branch; beam4pm submodule-gitlink dependency; wasm4pm `crates/eu_gate/` exclusion; ash_pplan `docs/sjira/` exclusion; ferroplan untracked-script `git add` gate; ex4pm tar do-not-commit |

## Findings

1. **Untracked-evidence-surface class (W673/W693 finding, fleet-wide)**: pin/court evidence in 5
   repos lives wholly or partly in untracked files — wasm4pm `tests/ontology/` (entire dir),
   ferroplan `scripts/check_airo.sh` + `docs/airo-risk-description.ttl`, autofde-lab `ontology/` +
   `tests/ontology/`, ash_pplan `docs/sjira/`, ex4pm tar (do-not-commit). A wave commit that adds
   only tracked modifications silently drops the evidence; each commit above names its untracked
   adds explicitly.
2. **beam4pm vendored-submodule gate**: W658b's ceiling edit is inside the `vendor/ggen-marketplace`
   submodule; integration must commit the submodule before the superproject gitlink bump, or the
   committed state references an uncommitted submodule head.
3. **ggen-marketplace branch gate**: wave commits land on `feat/aaif-gcp-roadmap-v26.10.5`, not
   main; merge is an explicit-request transition owned by the coordinator.
4. **Commit-order dependency**: only ggen-marketplace→xaas `ggen sync` is a hard ordering edge;
   all other repos are independent and can integrate concurrently after steps 1–3.

## Replay

- Every scoped porcelain line re-derivable: `git -C <repo> status --porcelain` against the
  branch/HEAD pairs listed above.
- Receipt corpus: `/Users/sac/xaas/docs/sjira/v26.10.6/plans/w6{58,58b,75,77,78,80,81,82,83,84,87,93,95}-*.md`, `w756-*.md`.
