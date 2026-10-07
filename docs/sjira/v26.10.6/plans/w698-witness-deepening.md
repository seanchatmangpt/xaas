# W698 — Witness Surface Deepening (unit courts)

- **Subject**: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6`
- **Standing**: PARTIAL_ALIVE — all 8 new courts pass on the exact subject; 2
  pre-existing defects surfaced (typed-refusal degradation), not repaired in this
  lane (tests-only scope).
- **Date**: 2026-10-07

## Scope

Added `test/xaas/witness/witness_surface_deepening_test.exs` (8 tests, Chicago
style: real Postgres sandbox, real Ash actions, real `:crypto` + real
OpenSSL-CLI signers — no mocks):

- **(a) write-once payload**: duplicate `(subject, payload_hash_hex)` ingest
  refused, row count invariant; attempted payload overwrite via the only update
  action refused outright with typed `NoSuchInput` `Ash.Error.Invalid`
  (stronger than "ignored": Ash refuses unknown inputs because
  `accept([])` + unknown-input refusal).
- **(b) kid uniqueness**: duplicate `kid` registration refused; original row
  untouched; distinct kids with same material both register (identity is on
  `kid` alone).
- **(c) verification write-once**: `record_verification` refuses after
  `verified=true` via both `Catalog.record_verification/2,3` and the raw
  `:record_verification` action; `verified_at` unchanged after refusal.
- **(d) 6 wire algorithms, real round-trips** (no fixture-absent hand-waving —
  every one is real): ES256 (secp256r1 ECDSA), Ed25519 (EDDSA), ES256K
  (secp256k1 ECDSA) via `:crypto` with negative controls; ML-DSA-65 via the
  real OpenSSL CLI (`pkeyutl -rawin`, FIPS 204, ~3309-byte sig) for both
  `ML-DSA-65` and `ML_DSA65` wire names, each with a tampered-message negative
  control.
- **(e) alias resolution**: `ES256K_RECOVERABLE` → `:es256k`,
  `ML_DSA65` → `:ml_dsa65` resolve through a real `Catalog.ingest/1` (receipts
  created, `skipped: []`, kids registered); unknown wire name
  (`SLH-DSA-SHA2-128s`) skipped with typed
  `:algorithm_not_in_admitted_enum`, zero rows written.
- **@moduletag :eu_ai_act** with in-file comment naming Art 18/74
  record-keeping candidates.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW698 \
  mix test test/xaas/witness/witness_surface_deepening_test.exs --include eu_ai_act
  → Result: 8 passed, 0 failures

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW698 \
  mix test test/xaas/witness/ --include eu_ai_act
  → Result: 43 passed, 9 excluded  (35 pre-existing witness tests still green)
```

ML-DSA negative-control `provider signature failure` stderr lines are expected
(the tampered-message OpenSSL verdicts), not failures.

## Findings (pre-existing, not repaired in this tests-only lane)

1. **Typed-refusal degradation on identity constraints.** Duplicate ingest of
   `CertifiedReceipt` returns `Ash.Error.Unknown` wrapping the raw
   `Ecto.ConstraintError` instead of a typed `Ash.Error.Invalid` — the DB index
   name (`witness_certified_receipts_subject_payload_hash_hex_index`) does not
   match the name Ash derives from the resource identity
   `:unique_subject_payload` (`..._unique_subject_payload_index`). Same for
   `VerificationKey` (`witness_verification_keys_kid_index` in DB vs
   `..._unique_kid_index` expected). Consumers relying on matching
   `%Ash.Error.Invalid{}` get an Unknown class instead; `Catalog.ingest/1`
   papers over this with its `existing_receipt/1` fallback. Repair direction:
   rename the identities (or add named `identity ... index_name`/migration
   index rename) so the constraint maps.
2. Minor: `Catalog.@supported_algorithms` is private, so the alias-resolution
   court exercises it behaviorally through `ingest/1` rather than directly.

## Environment / replay

- elixir 1.20.2-otp-28 / erlang 28.5.0.2 via asdf; `MIX_ENV=test`.
- `_build-laneW698` build root NOT deleted — `rm -rf` was denied by the
  permission system in this session; coordinator should delete it at
  integration per the lane-lease law.
- No commits made (per lane instruction); working tree carries only the new
  test file + this receipt.
