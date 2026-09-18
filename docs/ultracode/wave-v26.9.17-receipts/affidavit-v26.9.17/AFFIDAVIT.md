# Affidavit — SA2A release v26.9.17 qualification wave

Issued 2026-09-17 by wave-4 agent 5 of 8 (capability: cap-standing), from the
`affidavit` repo's own court (v26.6.22 `affi` CLI, 7-stage BLAKE3 certify pipeline).

## What is bound, and how

- **Native binding (BLAKE3 chain):** `receipt.json` is a sealed OCEL receipt of 14
  events (evt-0..evt-13). Events evt-1..evt-11 each carry the BLAKE3 commitment of
  the exact bytes of one file in `evidence/` (copied at issuance time). evt-0
  (init), evt-12 (pending-evidence), evt-13 (boundary) bind the issuance
  statements via stdin payloads. The rolling chain hash (`13672dfb…` claimed,
  recomputed and matched by the verifier) seals the whole history. Content
  address of the issued receipt: `67dc12107fa29a1e435ad22fd7b780a0f569b15ac54d0a0965494ffa2e5743c4`.
- **Manifest-only binding (sha256):** `MANIFEST.sha256` lists SHA-256 of each
  evidence copy. It exists for operators without the `affi` tool; the
  chain-native BLAKE3 commitments inside `receipt.json` are the authoritative
  binding. `receipt-view.json` is a derived human view (via `affi receipt show
  --format json`).

## Boundary — read before relying on this artifact

UNSUPPORTED(issue-affidavit, cryptographic-signature). The `sign`/`attest`/
`notarize` handlers of this repo are crypto-free structural stubs (no key
operation, no RFC-3161 TSA). This affidavit is **chain-verifiable, not
cryptographically signed**: an ACCEPT verdict from `affi receipt verify` proves
BLAKE3 chain tamper-evidence held (any single-byte mutation of any historical
event breaks chain_integrity), and nothing more. It does not prove an identity
bound the artifact. Owner pack must supply real Ed25519/Sigstore signing over
the chain hash before "sworn" is cryptographically true.

## Evidence set (evt order)

| evt | file | role |
|-----|------|------|
| 0 | — (init statement) | issuance context: court, branch, purpose |
| 1 | evidence/ORIENT-v26.9.17.md | wave orientation |
| 2 | evidence/boundary-ash-r2rml.md | r2 boundary receipt |
| 3 | evidence/boundary-bcinr.md | r3 boundary receipt |
| 4 | evidence/boundary-ggen.md | r4 boundary receipt |
| 5 | evidence/boundary-xaas.md | r5 boundary receipt |
| 6 | evidence/boundary-affidavit.md | r7 boundary receipt (this court) |
| 7 | evidence/boundary-beam4pm.md | beam4pm boundary receipt |
| 8 | evidence/boundary-autofde-lab.md | autofde-lab boundary receipt |
| 9 | evidence/boundary-ash-a2a.md | ash-a2a boundary receipt |
| 10 | evidence/boundary-ggen-igniter.md | ggen-igniter boundary receipt |
| 11 | evidence/zcode-connection-P0P1.md | zcode connection P0/P1 report |
| 12 | — (pending statement) | **pending, NOT bound:** `ep1-driver.md`, `ep1-observer.md` were absent at issuance; they require a follow-up affidavit when they land |
| 13 | — (boundary statement) | the UNSUPPORTED text above, inside the chain |

## Reproduction

```sh
affi receipt verify --receipt receipt.json   # exit 0 = ACCEPT [core/v1]
shasum -a 256 -c MANIFEST.sha256             # exit 0 = evidence copies intact
```

Court provenance: binary built in worktree `/tmp/uzc/affidavit-wt` on branch
`feat/v26.9.17-release-affidavit` (from `fix/affidavit-v26.9.17-boundary` tip
`3106f64`); no push, no PR, no merge. Issuance log: `/tmp/uzc/affi-court-v26.9.17/issuance.log`.
Full command/exit record: `/tmp/uzc/affidavit-issuance.md`.
