# W650v2 Receipt — Refusal Ledger Digest Question (v26.10.7 fleet seal)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (HEAD `ab0f3870`), artifact
  `docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json` — clean vs HEAD (no local
  modification).
- **Standing**: ALIVE — digest chain fully reconciled; both digests explained as one
  byte of difference; fresh-emit determinism witnessed this session.
- **Lane**: W650v2. No commit made (per lane contract).

## Digest chain

| digest (sha256) | provenance |
|---|---|
| `203fee7cd4ec9d7c68d4621469cac248c774a8c102ce6a1cc169f3132bea8f59` | W616b's recorded digest (receipt `w616-refusal-ledger.md`) — also what the emitter itself prints. **sha256 of the canonical JSON body, excluding the trailing newline.** |
| `6d1e4b89fa90c7489f848ced8d1adcae4bbee9fd608476f035c0b62f91334ea7` | W984cw4's recorded post-run on-disk sha256 (`docs/sjira/v26.10.6/plans/w984cw4-ops-probe.md:95`); sha256 of the on-disk file this session; **sha256 of the same canonical body plus the single trailing `\n`** that `emit()` appends on write. |

Verified computationally this session: sha256(bytes) = `6d1e4b89...`;
sha256(bytes with the trailing `\n` stripped) = `203fee7c...`. Same content,
different framing — **no content drift**.

## Fresh-emit determinism check (witnessed this session)

`mix xaas.export_refusal_ledger` run once with
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650V2`
(fresh lane build root, deleted at integration per fanout law). Result:

- Pre-run artifact snapshot (sha256 `6d1e4b89...`) and post-run artifact are
  **byte-identical** (`cmp` clean) — the emitter reproduces the committed bytes.
- The task printed `sha256: 203fee7c...` / `replay: MATCH` — its `emit()`
  computes the digest over `canonical_json` while writing
  `canonical_json <> "\n"` (`lib/xaas/operations/refusal_ledger_export.ex:161-167`),
  so the printed digest never equals the sha256 of the file it just wrote.

## Findings (for W616's owner — non-blocking)

1. **No regression**: the emitter is deterministic; W616's determinism gate holds
   at the byte level. The two "conflicting" digests in the receipts are the same
   artifact differing by one trailing-newline byte.
2. **Minor emitter defect (cosmetic, digest-spec mismatch)**:
   `Xaas.Operations.RefusalLedgerExport.emit/0` hashes the pre-write canonical
   string but persists body + `\n`, so `mix xaas.export_refusal_ledger`'s printed
   digest is not the sha256 of the on-disk file. Anyone verifying with
   `shasum -a 256` on disk will see `6d1e4b89...`, not the task's `203fee7c...`,
   and read it as drift (exactly what this lane was dispatched to adjudicate).
   Fix is one line: hash `canonical_json <> "\n"` (what is actually written) —
   W984cw4's on-disk convention is the one `shasum` agrees with.
3. W616b's receipt records the emitter's internal digest; W984cw4's records the
   on-disk digest. Both receipts are accurate as stated; the ambiguity is the
   emitter's framing, not either receipt's honesty.

## Verdict

Digest question **CLOSED — no drift**. The artifact on disk is byte-reproducible
by a fresh emit (W616 determinism gate holds); the two recorded digests differ
only by the write-time trailing newline. Suggested one-line emitter digest fix
filed as finding #2 above for W616's owner.
