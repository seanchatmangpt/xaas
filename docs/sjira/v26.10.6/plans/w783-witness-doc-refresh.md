# W783 — Witness-surface doc refresh (ash-configuration.md)

Standing: PARTIAL_ALIVE (doc-only lane; claims grounded in code + plan receipts
on this exact subject, HEAD `a0723bf6`, branch `feat/playwright-surface`).
Scope: only the Witness-surface section of
`docs/claude/diataxis/reference/ash-configuration.md`; no code, no build root,
no commit.

## Per-claim changes

1. **Stored vs wire algorithms + W698 round-trips** — replaced the bare
   4-atom algorithm list with: stored atoms `[:es256, :ed25519, :es256k,
   :ml_dsa65]` (`lib/xaas/witness/certified_receipt.ex:20`,
   `constraints: [one_of: @algorithms]` line 36), all 6 wire algorithms
   (4 atoms + `ES256K_RECOVERABLE`, `ML-DSA-65` aliases) round-trip real
   signatures per `docs/sjira/v26.10.6/plans/w698-witness-deepening.md`
   (section (d): ES256/Ed25519/ES256K via `:crypto`, ML-DSA-65 via real
   OpenSSL CLI `pkeyutl -rawin` FIPS 204, tampered-message negative controls).
2. **`:unique_kid` identity named** — VerificationKey bullet now names
   identity `:unique_kid` (`lib/xaas/witness/verification_key.ex:33`).
3. **W726: typed Invalid via Ash-derived index names** — new bullets state
   duplicates surface as typed `Ash.Error.Invalid` ("has already been taken"),
   backed by identities `:unique_subject_payload`
   (`lib/xaas/witness/certified_receipt.ex:49`) / `:unique_kid` with indexes
   renamed to Ash's derived names by
   `priv/repo/migrations/20261007000000_rename_witness_identity_indexes.exs`
   (guarded `ALTER INDEX ... RENAME`, reversible `down`). Cited from
   `docs/sjira/v26.10.6/plans/w726-witness-constraint-fix.md`.
4. **W709: idempotent-reuse ingest** — new bullet: `Catalog.ingest/1` reuses
   the existing receipt/key (byte-identical) on repeat ingest
   (`lib/xaas/witness/catalog.ex:115-117` existing-receipt reuse,
   `lib/xaas/witness/catalog.ex:152` kid-idempotent registration). Contract
   cited from `docs/sjira/v26.10.6/plans/w709-witness-durability.md`.

## Evidence

- Read: witness section (lines 139-171 pre-edit),
  `lib/xaas/witness/{catalog,certified_receipt,verification_key}.ex`,
  `priv/repo/migrations/20261007000000_rename_witness_identity_indexes.exs`,
  `docs/sjira/v26.10.6/plans/w{698,709,726}-*.md`.
- Verified on disk after edit: section updated, other sections untouched
  (edits confined between the "Resources:" list and the E2E-spec paragraph).
- Not executed: no test run (doc-only lane; facts sourced from executed
  courts W698/W709/W726 receipts).
