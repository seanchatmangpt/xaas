# W709 — Witness Catalog Ingest Durability Court

- **Subject**: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf6 (canonical checkout)
- **Standing**: ALIVE (lane-local; uncommitted diff: 1 new test file)
- **Backlog**: Witness.Catalog ingest path lacked a durability court

## Deliverable

`test/xaas/witness/catalog_durability_test.exs` — new file, Chicago-style
(real Ash actions over `Xaas.Repo` :manual sandbox, real fixtures under
`test/xaas/witness/fixtures/`, no mocks). `@moduletag :eu_ai_act` with the
Art. 12 record-keeping / Art. 74 post-market monitoring anchor in the
moduledoc.

## Court coverage (contracts asserted from code, not invented)

1. **Baseline ingest exact rows + idempotency** — ingest of the real
   affidavit `BASELINE.json` + `crypto_trust_kat.json` corpus creates
   exactly 2 `CertifiedReceipt` rows (es256, ml_dsa65; admitted vectors at
   corpus indices 0 and 2), receipt `payload_hash_hex` = SHA-256 of each
   vector's `message_hex` string, result `payload_hash_hex` = SHA-256 of
   raw baseline bytes. Second identical ingest: same payload hash, row set
   byte-identical — **idempotent reuse is the real contract**
   (`existing_receipt/1` re-admits a matching (subject, payload_hash) row),
   not a duplicate refusal.
2. **Tampered baseline bytes** — real contract is **distinguishable
   hashes, not refusal**: `baseline_payload_hash/1` hashes raw file bytes
   for path input, so one flipped byte changes `payload_hash_hex`
   (4f654d21→4f654d22 flip) while `subject_commit` is unchanged.
3. **Key rotation** — two distinct key materials under ES256 register
   distinct kids (3 keys total across the surface); each receipt carries
   the `verifying_key_hex` actually used; `record_verification` on the
   v1-key receipt leaves the v2-key receipt `verified == false`; after
   both verifications exactly 2 rows verified. Standing follows the key
   actually used.
4. **Unknown algorithm** — real contract is a **typed skip**
   (`{0, "DILITHIUM2", :algorithm_not_in_admitted_enum}` in `:skipped`),
   never a silent drop and never a row (0 receipts, 0 keys, no
   `:ingest_refused` error raised).

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW709 \
  mix test test/xaas/witness/catalog_durability_test.exs --include eu_ai_act
# Run 1 (initial): 2/4 passed — 2 lane defects caught and repaired:
#   (i) wrong expectation sha256("") vs sha256(message_hex) — test bug
#   (ii) corpus index 1 is the ES256+ML-DSA-65 hybrid (skipped) — test bug
# Run 2 (final):
#   Including tags: [:eu_ai_act]
#   ....
#   Finished in 1.2 seconds (1.2s async)
#   Result: 4 passed
# exit code 0
```

## Replay

```
cd /Users/sac/xaas && git apply  # not needed: file is untracked new file
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
  test/xaas/witness/catalog_durability_test.exs --include eu_ai_act
```

## Notes

- No lib/ changes; test-only diff, ≤12 files (1 file + this receipt).
- `_build-laneW709` deleted after the passing run per fanout cleanup law.
- Pre-existing environment noise observed but unrelated: PromEx/Grafana
  upload warnings (nxdomain) during test boot; `[os_mon]` shutdown notes.
