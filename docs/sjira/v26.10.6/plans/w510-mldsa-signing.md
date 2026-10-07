# W510 — ML-DSA-65 runtime-signed receipt witness

Wave: EU-AI-Act Ch6 Art.50 (dissertation Ch6), closing the w405 gap
"no witnessed runtime-signed receipt".

## What exists (fenced, read before write)

* `lib/xaas/witness/certified_receipt.ex` — `Xaas.Witness.CertifiedReceipt`
  Ash resource; `@algorithms [:es256, :ed25519, :es256k, :ml_dsa65]`;
  write-once payload fields, `:ingest` + `:record_verification` (write-once).
* `lib/xaas/witness/audit_chain.ex` — Ch4 Def 4.2 chain; `sig` is a
  pluggable verify callback; moduledoc explicitly reserves ML-DSA wiring to
  lane W510 and says nothing fakes a signature.
* `lib/xaas/witness/catalog.ex` — w434: `:ml_dsa65` assertion-exercised via
  `test/xaas/witness/fixtures/crypto_trust_kat.json` (KAT vectors ingested;
  ML-DSA-65 + ES256 admitted, hybrid/SLH skipped typed).
* JCS canonicalization: `Jcs.encode/1` (hex `jcs ~> 0.2`), the same encoder
  `Xaas.Deployment.ReleaseSnapshot.portable_digest/1` uses
  (`release_snapshot.ex:356`).
* `ash_affidavit` (path dep, `mix.exs:116`):
  `AshAffidavit.Signing.Keys` gates JWKS keys against the closed algorithm
  set incl. `ML_DSA65` (`keys.ex:23` `@algorithms`; `select/2` admits,
  PQ families structurally :ok pending AG1 envelope lengths). BUT the
  pinned wasm ABI exposes NO key-consuming sign/verify op —
  `AshAffidavit.Signing.verify_signature` returns
  `{:unsupported, %Refusal{code: :unknown_op}}` for `alg: "ML_DSA65"`
  (witnessed by `ash_affidavit/test/ash_affidavit_signing_courts_test.exs:348`).
  So the wasm surface cannot produce or check an ML-DSA-65 signature today.

## Signer choice (real crypto, no stubs)

OpenSSL 3.6.4 CLI (`/opt/homebrew/opt/openssl@3/bin/openssl`) implements
ML-DSA-65 (FIPS 204) natively. Used as a real subprocess via `System.cmd`
(Chicago-style real collaborator):

* `openssl genpkey -algorithm ML-DSA-65`
* `openssl pkeyutl -sign -rawin -inkey key.pem -in msg -out sig`
* `openssl pkeyutl -verify -rawin -pubin -inform DER -inkey pub.der
  -in msg -sigfile sig`

Pre-run live falsifier (2026-10-06, host shell): sign of `hello-receipt`
verified successfully; tampered message → `Signature Verification Failure`,
exit 1. ML-DSA-65 sig ~3309 bytes.

## The test

`test/xaas/witness/ml_dsa_signed_receipt_test.exs` — 4 tests:

1. Real ML-DSA-65 keypair signs the JCS-canonical receipt payload;
   signature verifies against the DER SPKI pubkey. Positive control.
2. Tampered payload (different subject → different JCS bytes) under the
   SAME signature fails verification. Negative control.
3. The real pubkey is admitted by `AshAffidavit.Signing.Keys.from_jwks` +
   `select/2` as `ML_DSA65` (w434 host gate exercised with REAL key
   material); an algorithm outside the closed set is typed-refused
   (`:bad_field`).
4. Full surface: payload → JCS → sign → ingest through
   `CertifiedReceipt :ingest` (`algorithm: :ml_dsa65`, real sig/SPKI hex) →
   read back → verify from STORED hex material → wire the real OpenSSL
   verification in as the `AuditChain` `sig` callback (`verify_chain: :ok`)
   → tampered digest chain rejected (`{:tampered, 0}`) →
   `:record_verification` write-once enforced.

## Integration seam (filed, not faked)

The only gap: `AshAffidavit.Signing.verify_signature` has no ML_DSA65 op
(pinned wasm ABI). When AG1/AG3 lands the key-consuming op, the test's
`write_and_verify/3` (System.cmd openssl) is the drop-in seam to replace
with the engine call — envelope fields and key material are already in the
engine's CTP-ENVELOPE-v1 shape law. Until then, signing runs host-side via
OpenSSL; no lib/ change was needed (contract respected: only this test file
and this plan doc written).

## Receipt fields

* Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW510 mix test test/xaas/witness/ml_dsa_signed_receipt_test.exs`
* Real tail (2026-10-06, exit 0):

  ```
  Running ExUnit with seed: 15007, max_cases: 32
  Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel, :eu_ai_act]
  ...
  Finished in 0.9 seconds (0.00s async, 0.9s sync)

  Result: 4 passed
  mix-exit=0
  ```

* Run caveat (disclosed): two UNTRACKED sibling-lane files on the shared
  canonical checkout did not compile at run time
  (`lib/xaas/actuation/quiescent_stop.ex` — missing `require Ash.Query`;
  `lib/xaas/semantics/counterfactual.ex` — TokenMissingError :217). They were
  moved aside for the run and restored byte-identical afterward (`git status`
  still `??` on both). Neither is a W510 file; no lib/ edit was made.
* Standing: ALIVE for the witnessed flow — real ML-DSA-65 runtime-signed
  receipt over JCS-canonical payload, positive + tamper-negative controls,
  persisted through `Xaas.Witness.CertifiedReceipt`, real sig callback in
  `Xaas.Witness.AuditChain`. PARTIAL_ALIVE remains on the engine seam:
  `AshAffidavit.Signing` has no ML_DSA65 op at the pinned wasm ABI.

## w405 claims-index correction this enables

> ML-DSA-65 runtime-signed receipt witnessed (OpenSSL 3.6.4 CLI subprocess,
> FIPS 204, over JCS-canonical payload; positive + tamper-negative controls;
> persisted through `Xaas.Witness.CertifiedReceipt` and used as the real
> `sig` callback of `Xaas.Witness.AuditChain`). Engine-side (`ash_affidavit`
> wasm) ML_DSA65 sign/verify remains UNSUPPORTED at the pinned ABI — seam
> documented.
