# W668 — AIRo wiring ledger verification (receipt)

> **Provenance note (read first)**: this receipt was **minted retroactively
> by lane W790 on 2026-10-07**, from the lane's existing verification artifact
> `docs/cro/artifacts/airo-wiring-ledger-verification-w668.md` and the twelve
> per-repo pin receipts in this directory. Lane W668 delivered the artifact
> but never minted a receipt in `plans/` (W781 finding 3); W790 wrote this
> file only to close that gap. Every claim below is sourced from the artifact
> or the cited pin receipts — W790 re-executed nothing. It is a receipt of
> record, not a re-verification.

## Subject

- **Verifying lane**: W668, xaas v26.10.6 campaign, 2026-10-07.
- **Object verified**: `/Users/sac/xaas/docs/cro/artifacts/airo-wiring-ledger.md`
  (consolidated AIRo wiring ledger, assembled by W639, 2026-10-06).
- **Verification artifact (primary evidence)**:
  `/Users/sac/xaas/docs/cro/artifacts/airo-wiring-ledger-verification-w668.md`
  — the only write made by lane W668 (plus a `/tmp/airo.ttl` vocab-cache
  restore, sha-identical to the pinned xaas copy).
- **Scope**: 14 repos, read-only verification plus one real xaas test run.

## Verdict

**14 repos: VERIFIED 14 / DRIFTED 0 / UNVERIFIABLE 0.**

Sub-checks (all from the artifact, observed 2026-10-07):

- 14 artifact paths exist with byte sizes matching the ledger exactly.
- 3 durable byte-verbatim vocab copies (xaas `priv/semantic/airo/airo.ttl`,
  ggen-marketplace `packs/ggen-platform-pack/ontology/airo.ttl`, ash_r2rml
  `test/fixtures/airo_vocabulary_snapshot.ttl`) all hash to pin
  `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`.
- All 14 TTLs parse clean under real Python rdflib.
- Cited test counts match on disk: gymact 4, autofde-lab 6, ash_a2a 9,
  wasm4pm 4, zcode-cli 4, ggen_igniter 4, ash_r2rml 6, beam4pm 8 court +
  3 canary, ash_affidavit 4, ash_surface 4.
- ggen and ferroplan `check_airo.sh` actually executed → PASS (after the
  `/tmp` vocab-cache restore).
- xaas mapping + pin tests executed for real: **14 passed, 1 skipped,
  exit 0**.

## Per-repo rows (from the artifact)

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
| w634 | beam4pm | `priv/airo_risk_description.ttl` 14,146 B; 179 triples; 11 passed = 8 court + 3 canary | exists, 14,146 B; rdflib 179 exact; court file 8 `test` blocks; canary `test/beam4pm_w601_map_update_dual_safe_test.exs` 3 `test` blocks | VERIFIED |
| w637 | ash_affidavit | `ontology/airo_risk_description.ttl` 12,084 B; 4 tests | exists, 12,084 B; rdflib OK (93); `test/airo_risk_description_test.exs` present, 4 `test` blocks | VERIFIED |
| w637 | ash_surface | `priv/airo_risk_description.ttl` 11,271 B; 4 tests | exists, 11,271 B; rdflib OK (90); `test/airo_risk_description_test.exs` present, 4 `test` blocks | VERIFIED |
| w638 | ferroplan | `docs/airo-risk-description.ttl` 5,417 B + `scripts/check_airo.sh`; 592 triples after vocab union | exists, 5,417 B; bare parse 34; 34 + 558 = 592, consistent; script executed → PASS | VERIFIED |

## Supporting pin receipts (plans/)

Thirteen per-repo pin receipts independently confirm individual ledger rows at
exact HEADs:

| receipt | repo | HEAD | confirmation |
|---|---|---|---|
| `w675-ash-surface-airo-pin.md` | ash_surface | `d55c576d11a2213a666c44f135c96e2f6baf44d0` | ledger row consistent; hardened with identity pins |
| `w677-gymact-airo-pin.md` | gymact | `20b3fd7ecc7563803207a61d8e4bdb521b4771fe` | row CONFIRMED CONSISTENT; 9-test deepening pin added |
| `w678-autofde-lab-airo-pin.md` | autofde-lab | `2a3d064e30df4da2bf465a2fbaaefe6e84da0325` | claims verified with evidence table |
| `w680-ex4pm-airo-pin.md` | ex4pm | `46bfcc8fac15889971a36b2e99c463d80b3f1712` | backlog "ex4pm CONSISTENT" claim under test confirmed |
| `w681-wasm4pm-airo-pin.md` | wasm4pm | (see receipt) | ALIVE — row w615/wasm4pm CONSISTENT, surface pinned |
| `w682-ash-pplan-airo-pin.md` | ash_pplan | `7eeaaa16bd9f8e76170c90617bcceef7b852d410` | surface committed at HEAD 7eeaaa1, CONFIRMED |
| `w683-zcode-cli-airo-pin.md` | zcode-cli | (see receipt) | CONSISTENT confirmed, all claims verified on disk |
| `w685-ash-r2rml-airo-pin.md` | ash_r2rml | (see receipt) | row accurate, no drift, CONSISTENT stands |
| `w686-ggen-igniter-airo-pin.md` | ggen_igniter | `b78a73e9…` | replay: `mix test test/airo_wiring_pin_w686_test.exs` |
| `w687-ggen-marketplace-airo-pin.md` | ggen-marketplace | `4bb5fbaff4ac8f1ace120e356d06d1b3ebe1cf86` | row w602 before/after claim table, verdicts recorded |
| `w690-ash-affidavit-airo-pin.md` | ash_affidavit | `8d90cc62716d12b12ec01253b3445131f8597acf` | ALIVE — row w637 verified CONSISTENT + identity pins |
| `w693-ferroplan-airo-pin.md` | ferroplan | `c03787687da4c0cd7d11d2f8b1bf1a9851ef8758` | row w638 claims VERIFIED; 8-test ExUnit pin lives in xaas tree (`test/xaas/semantics/ferroplan_airo_pin_test.exs`, deliberate routing deviation, recorded in the receipt) |
| `w695-ggen-airo-pin.md` | ggen | (see receipt) | consistent with observed reality |

Note: the pin-receipt set covers 13 repos (12 from W781's finding list plus
`w693-ferroplan-airo-pin.md`, found on disk at mint time); the artifact
additionally verified xaas itself (w600/w601, via the real test run in
Execution below), yielding the 14/14 total. w680 additionally covers ex4pm
(not among the artifact's 14 rows; recorded as extra confirmation, not
counted).

## Commands (as recorded in the artifact)

Verification method (read-only across the 14 repos): artifact/TTL existence +
byte sizes via `ls`; sha256 via `shasum -a 256`; TTL parses via real Python
`rdflib`; cited test counts grep-verified in each named test file; ggen and
ferroplan `scripts/check_airo.sh` executed.

xaas execution (the one real test run, completed 2026-10-07 00:59 local,
exit 0):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW668 \
  mix test test/xaas/semantics/airo_risk_mapping_test.exs \
          test/xaas/semantics/airo_vendored_pin_test.exs
```

Observed output:

```
Running ExUnit with seed: 157251, max_cases: 32
..............
Finished in 0.09 seconds (0.08s async, 0.01s sync)
Result: 14 passed, 1 skipped
[exited with code 0]
```

(The 7-test w601 claim is subsumed: the two files together yield 14 passed /
1 skipped — all mapping + vendored-pin tests pass on the current tree.)

## Verification tails (replay)

- xaas: the exact command above, under the pinned toolchain, with
  `MIX_BUILD_ROOT` of your choosing; expect `14 passed, 1 skipped`, exit 0.
- ggen / ferroplan: `bash scripts/check_airo.sh` in each repo (requires a
  `/tmp/airo.ttl` vocab cache or the scripts' own restore path; see Drift).
- Per-repo TTL claims: `shasum -a 256` the three durable vocab copies and
  compare to `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`;
  parse each TTL with Python rdflib; grep the cited test files for the cited
  block counts.
- ggen_igniter replay: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW686 mix test
  test/airo_wiring_pin_w686_test.exs` in `/Users/sac/ggen_igniter`.
- ferroplan pin replay (w693): `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
  MIX_BUILD_ROOT=<root> mix test test/xaas/semantics/ferroplan_airo_pin_test.exs`
  in `/Users/sac/xaas`.

## Cross-checks and drift (recorded, honest)

- **HEAD SHAs**: ledger rows cite "@ HEAD" with no pinned SHA, so no
  claim-vs-HEAD comparison was possible at verification time (recorded, not
  counted as drift). Observed HEADs: xaas `a0723bf6`, ggen-marketplace
  `4bb5fbaf`, gymact `20b3fd7e`, autofde-lab `2a3d064e`, ash_a2a `b588c55c`,
  ggen `bc4d2390`, wasm4pm `32deb59f`, zcode-cli `eb97f76b`, ggen_igniter
  `b78a73e9`, ash_r2rml `b86a6a66`, beam4pm `813eb924`, ash_affidavit
  `8d90cc62`, ash_surface `d55c576d`, ferroplan `c0378768`.
- **Drift 1 — environment**: `/tmp/airo.ttl` (ledger sha-table row 4) was
  missing at verification time; ephemeral cache only, restored from the
  pinned xaas copy (sha-identical); both check scripts then PASS. Durable
  copies intact.
- **Drift 2 — script hygiene**: ggen + ferroplan `check_airo.sh` print FAIL
  but exit 0 when the `/tmp` vocab is absent (pipe masking; not fail-closed).
  Hardening follow-up for the script owners; no repo content drift.
- **Carry-forward #1**: all AIRo work remains uncommitted on the canonical
  checkouts; integration commits are the coordinator's.
- **Carry-forward #3**: W601 disclosed a mid-lane concurrent overwrite of
  `lib/xaas/semantics/airo_risk_mapping.ex`; the re-run of its test is
  recorded in Execution above.
- **Build-root lease**: `_build-laneW668` (437 MB, xaas) was W668's lease,
  to be deleted at integration per the cleanup law.

## Standing

- **W668 verification**: PARTIAL_ALIVE — the 14/14 verdict is grounded in a
  real, on-disk, partially executed verification (real sha256, real rdflib
  parses, real script executions, one real ExUnit run) but the AIRo surfaces
  themselves remain uncommitted on their checkouts; ALIVE for each repo
  requires the coordinator's integration commit plus a replay at the merged
  head. Per-repo pin standing is carried by the twelve receipts in the table
  above (several self-declared ALIVE at their exact HEADs).
- **Retroactive mint**: this receipt's standing is that of its sources — it
  adds no new execution. Falsifier for the mint itself: any claim in the
  artifact contradicted by the current tree, or a cited pin receipt that does
  not exist in `plans/`.
- **Falsifier (original verification)**: any of the 14 rows failing its
  recorded sub-check on replay — wrong byte size, pin-sha mismatch, rdflib
  parse failure, test-count mismatch, or `check_airo.sh` FAIL on a restored
  cache.
