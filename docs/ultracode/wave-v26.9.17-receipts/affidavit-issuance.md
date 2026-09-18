# Receipt — affidavit issuance for SA2A release v26.9.17 (wave-4 agent 5 of 8, cap-standing)

Date: 2026-09-17. Capability: issue a real affidavit over the wave's evidence using the
affidavit repo's own court, then independently verify it. Subject repo: /Users/sac/affidavit.
Isolation: worktree /tmp/uzc/affidavit-wt, branch `feat/v26.9.17-release-affidavit` created
from `fix/affidavit-v26.9.17-boundary` (tip `3106f64`). Main checkout untouched (2 dirty
Cargo files left alone). No push, no PR, no merge.

## Environment deviation (documented, narrow)

- Committed build state at tip `3106f64` does not compile: registry `wasm4pm-compat`
  26.6.13 fails (550 errors). The operator's main checkout carries uncommitted drift
  (`[patch.crates-io] wasm4pm-compat = { path = "/Users/sac/wasm4pm-compat" }`), documented
  in /tmp/uzc/boundary-affidavit.md, under which the boundary agent's build passed.
- Lawful reproduction inside my own worktree: appended the same `[patch.crates-io]` section
  (with provenance comment) to /tmp/uzc/affidavit-wt/Cargo.toml and let cargo re-resolve
  Cargo.lock to the local path 26.8.7. Both files left uncommitted. No source bytes changed.
- `cargo build --release` in worktree → **exit 0** (Finished release, 57.12s).

## Issuance commands + exit codes (real binary, cwd = /tmp/uzc/affi-court-v26.9.17)

Working state `.affi/working.json` kept OUT of the artifact dir. Log: issuance.log.

| # | command (abbreviated) | exit |
|---|-----------------------|------|
| 1 | `affi receipt emit --r#type init --object release:v26.9.17 --payload -` (stdin issuance statement) | 0 |
| 2–12 | `affi receipt emit --r#type witness --object <file>:file --payload /tmp/uzc/affidavit-v26.9.17/evidence/<file> --format json` for the 11 evidence files (evt-1..evt-11, full BLAKE3 commitments captured) | 0 ×11 |
| 13 | `affi receipt emit --r#type pending-evidence --object release:v26.9.17 --payload -` (ep1-driver.md, ep1-observer.md absent at issuance → NOT bound) | 0 |
| 14 | `affi receipt emit --r#type boundary --object affidavit:issuance --payload -` (UNSUPPORTED text, inside the chain) | 0 |
| 15 | `affi receipt assemble --out /tmp/uzc/affidavit-v26.9.17/receipt.json` → content address `67dc12107fa29a1e435ad22fd7b780a0f569b15ac54d0a0965494ffa2e5743c4` | **0** |
| 16 | `affi receipt verify --receipt receipt.json` → stderr `verdict: ACCEPT [core/v1] — all stages passed`; all 7 stages PASS; 14 events | **0** |
| 17 | `affi receipt show --receipt receipt.json --format json` → receipt-view.json | 0 |

Evidence set bound (evt order): ORIENT-v26.9.17.md, boundary-ash-r2rml.md, boundary-bcinr.md,
boundary-ggen.md, boundary-xaas.md, boundary-affidavit.md, boundary-beam4pm.md,
boundary-autofde-lab.md, boundary-ash-a2a.md, boundary-ggen-igniter.md,
zcode-connection-P0P1.md. PENDING (not bound, recorded inside the chain as evt-12):
ep1-driver.md, ep1-observer.md — require a follow-up affidavit when they land.

## Independent verification + falsifiers (all on THIS artifact)

1. Verify issued receipt → **exit 0**, ACCEPT [core/v1], 7/7 stages PASS (command 16 above).
2. Tamper falsifier on a COPY (never the original): `cp receipt.json tampered.json` +
   `sed 's/"event_type":"init"/"event_type":"forged"/'` (first attempt with `"init"` spaced
   matched nothing — canonical JSON has no space after colon; caught by `cmp` exit 0, redone
   on the real bytes, `cmp` exit 1).
   `affi receipt verify --receipt tampered.json` → **exit 1** (ADR-3 deserialization/chain
   gate), stderr: `chain hash mismatch: receipt claims 13672dfb95354e00…, recomputed
   2b99ec61530ba0aee1101f55a87b2725b0dd622cdff2bbf7d9bb5d2229051da6`. Teeth real on this artifact.
3. Binding-bite falsifier (does a commitment actually bind evidence bytes?): recomputed
   commitments via scratch `receipt emit --format json`:
   - pristine copy of boundary-affidavit.md → `d91073a4f778089016a21016407a69106acfb1aafded1bb801226adb50dd980a`
     = EXACTLY evt-6's issued commitment (binding reproducible from staged bytes);
   - copy + 1 appended byte → `05cff986c3a93caaf65e1c61f9bf728cdbd92b3f02f04e37bddcd491dc35bdbd`
     (completely different — commitment bites).

## Artifact: /tmp/uzc/affidavit-v26.9.17/

```
70183ed01241700dc9aa061842a82973238e579cfa504cc48fdb1a1b44876336  receipt.json
76ceb5e8516639e5836aa9d50eaf92f6f24f2197fa98b4e101eaf890b875f8b9  receipt-view.json
e0eb6976f65dd7ccc1e2777d9f5b8e635012f6da7b0c31a63f7f0363a58a4ec6  MANIFEST.sha256
aae2a23c4778090cf490eaa8db8533420fff0057de43e1fbc13bd60630efd1c1  AFFIDAVIT.md
```
`shasum -a 256 -c MANIFEST.sha256` (11 evidence files) → all OK, **exit 0**.
SHA-256 of the evidence copies are in MANIFEST.sha256; the authoritative per-file binding is
the BLAKE3 commitments inside receipt.json (native), MANIFEST.sha256 is the sha256
manifest-only convenience copy. AFFIDAVIT.md states the issuance, the evt→file table, and the
reproduction commands.

## UNSUPPORTED boundary (restated, not papered over)

UNSUPPORTED(issue-affidavit, cryptographic-signature). sign/attest/notarize in this repo are
crypto-free structural stubs; no cryptography executes. The issued affidavit is
**chain-verifiable (BLAKE3 rolling-hash chain, 7-stage pipeline), NOT cryptographically
signed**. ACCEPT proves tamper-evidence only, not signer identity. This is stated inside the
chain (evt-13), in AFFIDAVIT.md, and here.

## 比 + what the operator did NOT have to write

Artifact bytes: receipt.json 3061 B (tool-sealed), receipt-view 4632 B (tool-derived),
MANIFEST/AFFIDAVIT issued around them. Zero source bytes authored in the subject repo; only
the mirrored `[patch]` block (3 lines + comment) reproduces the operator's own documented
drift. The operator wrote nothing: worktree, build, all 18 court commands, 3 falsifier runs,
manifest, hashes, and this receipt.

Standing: verification/tamper-evidence court exercised ALIVE on the exact issued artifact;
signing sub-surface UNSUPPORTED as ledgered. Issuance standing: **ALIVE** (with the typed
UNSUPPORTED element).
