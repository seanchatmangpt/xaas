# W637 — ash_affidavit + ash_surface AIRo risk descriptions (AIRo wiring wave)

- **Repos**: /Users/sac/ash_affidavit, /Users/sac/ash_surface (one canonical checkout each; no commit — coordinator owns integration).
- **Scope honored**: per repo exactly one TTL + one test file, plus this plan. Nothing else touched; no git commands run in either repo.
- **Vocabulary**: AIRo 1.0 per W600 — `https://w3id.org/airo#`, vendored in xaas at `priv/semantic/airo/airo.ttl`, sha256 `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469` (DelaramGlp/airo@6c67de43).
- **Standing**: ALIVE (both artifacts on disk + 4/4 ExUnit green in private lane build roots, pinned toolchain).

## Subjects

| repo | TTL | test |
|---|---|---|
| ash_affidavit | `ontology/airo_risk_description.ttl` | `test/airo_risk_description_test.exs` |
| ash_surface | `priv/airo_risk_description.ttl` | `test/airo_risk_description_test.exs` |

## Mapping — ash_affidavit (crypto trust plane = `w637:AffidavitCryptoTrustPlane`, airo:AISystem)

**RiskSources** (2, real documented hazards):

| id | hazard | status |
|---|---|---|
| RS-1 `EngineMldsaUnsupported` | pinned wasm ABI exposes no key-consuming ML_DSA65 sign/verify op — `AshAffidavit.Signing.verify_signature/4` returns `{:unsupported, %Refusal{code: :unknown_op}}` for `alg: "ML_DSA65"` (witnessed at `test/ash_affidavit_signing_courts_test.exs:348`; w510's seam) | OPEN at pinned ABI; bridged consumer-side by the W510 host-side OpenSSL ML-DSA-65 flow |
| RS-2 `KeyManagementExposure` | JWKS admission is structural only; PQ families (ML_DSA65, SLH_DSA_SHA2_128s, HYBRID_ES256_ML_DSA65) admitted `:ok` pending AG1 envelope lengths | BOUNDED — closed algorithm set, out-of-set keys typed-refused by `select/2` |

**RiskControls** (5, all real paths): `JwksClosedAlgorithmGate` (signing/keys.ex `@algorithms` closed set, `from_jwks/2` typed refusals, `select/2`) · `TypedUnsupportedRefusal` (signing.ex + ops.ex `{refused, trap, unsupported}` family, refusal.ex) · `PinnedEngineDigestGate` (engine_load.ex pinned SHA-256 + `:wasm_import_surface_mismatch`/`:wasm_missing_export`, abi.ex `@abi_version 1`, pinned wasm court) · `SigningCourts` (signing/pin/refusal courts + this structural court) · `HostSideMldsaSeam` (cross-repo, xaas `test/xaas/witness/ml_dsa_signed_receipt_test.exs` — described, not VIA).

Qualitative: hasLikelihood Low, hasSeverity Medium (downstream certification integrity).

## Mapping — ash_surface (projection surface = `w637:ProjectionSurface`, airo:AISystem)

**RiskSources** (2, real documented hazards):

| id | hazard | status |
|---|---|---|
| RS-1 `GeneratedCodeShadowing` | generated/projected code shadowing the lib/ source of truth; guard class = `aex:fixtureOnly` markers + `100_projection_isolation_contract.rq` (ggen-marketplace ash-extension-pack — cross-repo, described not VIA); in-repo: finish-determinism-027 shadow-double re-point ledgered in HANDWRITTEN.md; pack spec surface `ontology.ttl` (`surf:AshSurfaceSpec`, authorship origin declared in-file) | MITIGATED by the fixtureOnly isolation guard + authorship ledger |
| RS-2 `VocabularyViolation` | a crossing uses a standing/refusal outside the closed vocabulary (bare `:REFUSED`, unreasoned refusal, injected characters in a refusal code) | BOUNDED — `Standing.validate!` raises, refusal class must be `:"REFUSED_*"` naming its reason |

**RiskControls** (5, all real paths): `StandingValidateAdmission` (`lib/ash_surface/standing.ex` validate!/valid? + standing_test.exs + standing_evidence_adversarial_test.exs) · `VocabularyGuard` (`lib/ash_surface/vocabulary.ex` @refusal_prefix/base_standings/refusal_code? + vocabulary_test.exs + vocabulary_drift_test.exs) · `FixtureOnlyIsolationGuard` (cross-repo pack law + in-repo `ontology.ttl` authorship origin + HANDWRITTEN.md) · `SurfaceTestCourts` (verifier/transformer/spark-parity/composition courts; the 1068-line-id EU-AI-Act corpus itself lives in xaas `docs/eu_ai_act/corpus.json` — described, not VIA, so the in-repo path check stays truthful) · `ZodDecodeBoundaryGuard` (`lib/ash_surface/projectors/js/zod_guard.ex` + `test/ash_surface/decode_boundary_zod_guard_test.exs`).

Qualitative: hasLikelihood Low, hasSeverity Medium (consumer surface fidelity).

## Verification (executed)

1. All VIA-cited paths asserted on disk by the path-exists tests (not eyeballed).
2. Commands (pinned toolchain `elixir 1.20.3-otp-28 / erlang 28.3` per each repo's `.tool-versions`, asdf shims on PATH):

```
cd /Users/sac/ash_affidavit && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  MIX_BUILD_ROOT=_build-laneW637a mix test test/airo_risk_description_test.exs
```

tail (exit 0):

```
Excluding tags: [:pack_root, :ext_pack]
....
Finished in 0.02 seconds (0.02s async, 0.00s sync)

Result: 4 passed
```

```
cd /Users/sac/ash_surface && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  MIX_BUILD_ROOT=_build-laneW637b mix test test/airo_risk_description_test.exs
```

tail (exit 0):

```
==> ash_surface
Compiling 57 files (.ex)
Running ExUnit with seed: 491367, max_cases: 32
....
Finished in 0.03 seconds (0.03s async, 0.00s sync)

Result: 4 passed
```

Both verdicts: **PASS, 4/4 each, exit 0** (first affidavit run had a `use of operator > has no effect` warning on the byte-size line — fixed to `assert byte_size(content) > 2_000` in both tests before the recorded runs; ash_surface compiled clean first pass).

## Notes for coordinator

- Lane build roots `_build-laneW637a` (ash_affidavit) and `_build-laneW637b` (ash_surface) are leases — delete at integration per the cleanup law.
- Cross-repo citations (ggen-marketplace pack fixtureOnly law; xaas W510 seam + EU-AI-Act corpus) are deliberately inside `dcterms:description`, never `VIA`, so each repo's in-repo path-exists assertion stays truthful (W635 precedent).
- Fixture changes disclosed per lane brief: none — only the four files listed above plus this plan.
