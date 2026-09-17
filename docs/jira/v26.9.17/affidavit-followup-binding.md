# Affidavit Follow-Up Binding — close evt-12 pending-evidence with the episode record

## Summary

The wave affidavit (`/tmp/uzc/affidavit-v26.9.17/`, BLAKE3 chain, verify
ACCEPT 7/7, tamper teeth proven) bound 11 boundary receipts but recorded
`pending-evidence` in-chain for `ep1-driver.md` + `ep1-observer.md` (absent
at issuance), and predates `ep2-replay.md`, `certify-prep.md`,
`hook-court.md`, and `ledger-closure.md`. The chain itself names this
follow-up as owed.

## Status

BLOCKED — on the episode/certify tickets that produce the final evidence
(`p2-lease-cycle-redispatch.md`, `episode2-real-replay.md`,
`op-release-tag-cut.md`).

## Scope

1. Assemble the final evidence set: the two ep1 receipts (final versions),
   ep2, certify (post-tag 12/12), hook-court (post-restart re-receipt),
   ledger-closure, updated RELEASE-STATE.
2. Issue the follow-up affidavit through the real court (worktree build per
   `affidavit-issuance.md` — or the clean-checkout build once
   `affidavit-buildability-d4.md` lands), binding each file's BLAKE3
   commitment; reference the prior chain (linked artifacts, not a replacement).
3. Verify (exit 0, ACCEPT), tamper falsifier on a copy (exit 1), manifest
   check; place beside the first artifact; update RELEASE-STATE
   `affidavit-issued` rows for e1/e2.
4. Restate the typed boundary in-artifact: chain-verifiable, NOT
   cryptographically signed (UNSUPPORTED(issue-affidavit,
   cryptographic-signature) stands until the stubs become real crypto).

## Key Invariant(s)

- The original chain is immutable — follow-up EXTENDS evidence; nothing is
  re-issued or backdated.
- Pending-evidence markers must resolve or persist honestly (never silently
  drop).

## Relationship to Existing Work

- `affidavit-issuance.md` (issuance protocol + evt-12); feeds
  `release-certification-final.md` (m-certify-release requires
  `affidavit-issued` for BOTH episodes).

## Falsifiers / What Would Defeat This

- Follow-up verifies but binds files whose hashes do not match the current
   receipts (stale evidence bound).
- A claim in the artifact stronger than the UNSUPPORTED signing boundary
   allows.

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | affidavit feat/v26.9.17-release-affidavit (worktree) | first artifact: assemble→0, verify→0 ACCEPT, tamper→1 | episode evidence → follow-up chain → verify |
