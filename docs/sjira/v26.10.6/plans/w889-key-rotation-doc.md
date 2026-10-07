# W889 — Witness verification-key rotation semantics documented

- Subject: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface (lane W889, no commit)
- O*: W709 receipt `docs/sjira/v26.10.6/plans/w709-witness-durability.md` (lines 30-40: distinct kids; `verifying_key_hex` binding; v1-vs-v2 verified isolation; typed skip for unknown algorithm, 0 rows); court `test/xaas/witness/catalog_durability_test.exs`.
- μ: hand-written docs-only edit (irreducible residue; no generator exists for diataxis reference prose).

Diff (1 file, +14/-0):

`docs/claude/diataxis/reference/actuation-and-semantics.md`
- L340-349: new `### Witness verification-key semantics (key rotation)` subsection, placed at the end of the EU-AI-Act semantics layer section (witness surface is part of that layer, immediately before `## Digest forms`):
  - L343-345: distinct key materials under ES256 → distinct kids, all retained in catalog. [w709 L31-32]
  - L346-348: receipt carries `verifying_key_hex` actually ingested; `record_verification` binds standing to that key; v1 verification leaves v2 receipt `verified == false`. [w709 L32-35]
  - L349-352: unknown algorithm → typed skip `{0, "DILITHIUM2", :algorithm_not_in_admitted_enum}` in `:skipped`, never a row, no `:ingest_refused`. [w709 L38-41]
  - L354: court + W709 receipt citations.

Commands / exits:
- Content sourced by reading the two files (sed line ranges, exit 0; one early probe exited 1 due to zsh `===` glob, recovered, no file touched).
- Post-edit verification: `sed -n '340,357p' docs/claude/diataxis/reference/actuation-and-semantics.md` → block present, section heading intact, digest section follows unchanged. Exit 0.

Verification ladder: reference-only diff; no build/test touched (docs-only lane, no build root per dispatch). Facts verified against W709 receipt text line-by-line as cited above.

Standing: ALIVE (docs committed to working tree; integration commit owned by coordinator).
