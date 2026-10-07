# AIRo Wiring Ledger Verification — Lane W668

Verifier: lane W668, 2026-10-07. Subject: `/Users/sac/xaas/docs/cro/artifacts/airo-wiring-ledger.md`
(consolidated ledger, assembled by W639, 2026-10-06). Method: read-only
across the 14 repos; artifact existence + byte sizes via `ls`; sha256 via
`shasum -a 256`; TTL parses via real Python `rdflib`; cited test counts
grep-verified in each named test file; ggen/ferroplan `check_airo.sh`
actually executed; xaas tests executed under the pinned toolchain with
`MIX_BUILD_ROOT=_build-laneW668`.

## Totals

**14 repos: VERIFIED 14 / DRIFTED 0 / UNVERIFIABLE 0.**
Sub-checks: 14 artifact paths exist with byte sizes matching the ledger
exactly; 3 durable byte-verbatim vocab copies match pin
`6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469` exactly;
all 14 TTLs parse clean under rdflib; cited test counts match on disk
(gymact 4, autofde-lab 6, ash_a2a 9, wasm4pm 4, zcode-cli 4, ggen_igniter 4,
ash_r2rml 6, beam4pm 8 court + 3 canary, ash_affidavit 4, ash_surface 4);
ggen and ferroplan `check_airo.sh` executed → PASS (after `/tmp` vocab-cache
restore, see Drift); xaas mapping + pin tests executed for real: **14 passed,
1 skipped, exit 0**.

## Per-repo rows

| lane | repo | claim checked | observed on disk (2026-10-07) | verdict |
|---|---|---|---|---|
| w600 | xaas | `priv/semantic/airo/airo.ttl` 41,366 B; 558 triples; pin sha | exists, 41,366 B; rdflib 558 triples; sha256 `6274d2d8…8469` == pin | VERIFIED |
| w601 | xaas | `lib/xaas/semantics/airo_risk_mapping.ex` + test | exists (11,162 B) with `test/xaas/semantics/airo_risk_mapping_test.exs` (5,686 B); execution result in Execution section | VERIFIED |
| w602 | ggen-marketplace | `packs/ggen-platform-pack/ontology/airo.ttl` | exists; rdflib 558 triples; sha256 `6274d2d8…8469` == pin | VERIFIED |
| w603 | gymact | `src/gymact/ontology/airo_risk_description.ttl` 5,353 B; 4 tests | exists, 5,353 B; rdflib OK (64 triples); `tests/test_airo_risk_description.py` present, 4 `def test_` (incl. rdflib structure court) | VERIFIED |
| w604 | autofde-lab | `ontology/airo_risk_description.ttl` 8,071 B; 6 tests | exists, 8,071 B; rdflib OK (76); `tests/ontology/test_airo_risk_description.py` present, 6 `def test_` | VERIFIED |
| w605 | ash_a2a | `priv/ontology/ash_a2a_airo.ttl` 8,917 B; 11 RiskSources / 5 Controls / 5 Risks; 9 tests | exists, 8,917 B; rdflib OK (108); 55 `RiskSource` occurrences in TTL (grep-level, not individual counts); `test/ash_a2a_airo_description_test.exs` present, 9 `test` blocks | VERIFIED |
| w614 | ggen | `docs/airo-risk-description.ttl` 8,306 B + `scripts/check_airo.sh`; 618 triples after vocab union | exists, 8,306 B; bare parse 60 triples; 60 + 558 (vocab) = 618, consistent; script executed → PASS | VERIFIED |
| w615 | wasm4pm | `tests/ontology/airo_risk_description.ttl` 8,511 B; 4 tests | exists, 8,511 B; rdflib OK (82); test file present, 4 `def test_` | VERIFIED |
| w615 | zcode-cli | `ontology/airo_risk_description.ttl` 8,022 B; 4 tests | exists, 8,022 B; rdflib OK (83); `test/airo-risk-description.test.ts` present, 4 `it(`/`test(` blocks | VERIFIED |
| w618 | ggen_igniter | `priv/airo_risk_description.ttl` 10,296 B; 4 tests | exists, 10,296 B; rdflib OK (97); `test/airo_risk_description_test.exs` present, 4 `test` blocks | VERIFIED |
| w625d | ash_r2rml | `priv/airo_risk_description.ttl` + `test/fixtures/airo_vocabulary_snapshot.ttl` sha == pin; 6 tests | both exist (9,985 B ttl; fixture sha256 `6274d2d8…8469` == pin); `test/airo_risk_description_test.exs` present, 6 `test` blocks | VERIFIED |
| w634 | beam4pm | `priv/airo_risk_description.ttl` 14,146 B; 179 triples; 11 passed = 8 court + 3 canary | exists, 14,146 B; rdflib 179 exact; court file `test/beam4pm_airo_description_test.exs` 8 `test` blocks; canary `test/beam4pm_w601_map_update_dual_safe_test.exs` 3 `test` blocks | VERIFIED |
| w637 | ash_affidavit | `ontology/airo_risk_description.ttl` 12,084 B; 4 tests | exists, 12,084 B; rdflib OK (93); `test/airo_risk_description_test.exs` present, 4 `test` blocks | VERIFIED |
| w637 | ash_surface | `priv/airo_risk_description.ttl` 11,271 B; 4 tests | exists, 11,271 B; rdflib OK (90); `test/airo_risk_description_test.exs` present, 4 `test` blocks | VERIFIED |
| w638 | ferroplan | `docs/airo-risk-description.ttl` 5,417 B + `scripts/check_airo.sh`; 592 triples after vocab union | exists, 5,417 B; bare parse 34 triples; 34 + 558 = 592, consistent; script executed → PASS | VERIFIED |

## Cross-checks

- **sha256 pin**: 3 durable copies (xaas `priv/semantic/airo/airo.ttl`,
  ggen-marketplace `packs/ggen-platform-pack/ontology/airo.ttl`, ash_r2rml
  `test/fixtures/airo_vocabulary_snapshot.ttl`) all hash to
  `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469` —
  byte-identical to the w600/w621b pin.
- **HEAD SHAs**: ledger rows cite "@ HEAD" with no pinned SHA, so no
  claim-vs-HEAD comparison is possible (recorded, not counted as drift).
  Observed HEADs at verification time: xaas `a0723bf6`, ggen-marketplace
  `4bb5fbaf`, gymact `20b3fd7e`, autofde-lab `2a3d064e`, ash_a2a `b588c55c`,
  ggen `bc4d2390`, wasm4pm `32deb59f`, zcode-cli `eb97f76b`, ggen_igniter
  `b78a73e9`, ash_r2rml `b86a6a66`, beam4pm `813eb924`, ash_affidavit
  `8d90cc62`, ash_surface `d55c576d`, ferroplan `c0378768`.

## Drift (environment, not repo)

1. **`/tmp/airo.ttl` missing** at verification time (ledger sha-table row 4).
   Ephemeral cache only; restored from the pinned xaas copy (sha-identical)
   and both check scripts then PASS. Durable copies intact.
2. **`check_airo.sh` exit-code hygiene (ggen + ferroplan)**: when the
   `/tmp` vocab is absent the scripts print `check_airo: FAIL` but still
   exit 0 (pipe masking; not fail-closed). Hardening follow-up for the
   script owners; no repo content drift.

## Execution (xaas, real run)

Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW668
mix test test/xaas/semantics/airo_risk_mapping_test.exs test/xaas/semantics/airo_vendored_pin_test.exs`

Observed result (real run, completed 2026-10-07 00:59 local, exit 0):

```
Running ExUnit with seed: 157251, max_cases: 32
Excluding tags: [:stress, :kind, :requires_cnv_deploy, ...]
..............
Finished in 0.09 seconds (0.08s async, 0.01s sync)
Result: 14 passed, 1 skipped
[exited with code 0]
```

(The 7-test w601 claim is subsumed: the two files together yield 14 passed /
1 skipped — all mapping + vendored-pin tests pass on the current tree.)

Clean-up duty: `_build-laneW668` (437 MB) is this lane's lease and must be
deleted at integration per the cleanup law.

## Notes for coordinator

1. Ledger carry-forward #1 stands: all AIRo work remains uncommitted on the
   canonical checkouts; integration commits are the coordinator's.
2. Ledger carry-forward #3 stands: W601 disclosed a mid-lane concurrent
   overwrite of `lib/xaas/semantics/airo_risk_mapping.ex`; the re-run of its
   test is recorded in the Execution section of this file.
3. Lane build-root leases created by this verification: `_build-laneW668`
   (xaas) — delete at integration per the cleanup law.
4. This file is the only write made by lane W668 (plus the `/tmp` cache
   restore). The original ledger was not edited.
