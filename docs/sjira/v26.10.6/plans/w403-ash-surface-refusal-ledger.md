# W403 — CRO ash_surface refusal ledger (2026-10-06, lane W403)

Subject: `/Users/sac/ash_surface` (read-only; no commit). Backfill stub: the
artifact landed before its plan receipt; evidence is the artifact itself.

Artifact: `docs/cro/artifacts/ash-surface-refusal-ledger-v26.10.6.md`
(CRO-loop validation-pack item). Evidence: `grep -oE 'REFUSED_[A-Z_]+'` over
`/Users/sac/ash_surface/lib/` and `test/`, plus targeted reads of
`lib/ash_surface/vocabulary.ex` and `lib/ash_surface/standing.ex`; every
cited path in the ledger resolves against the ash_surface checkout; zero
in-repo fabrication findings (artifact-integrity audit verdict SHIP-READY).

Falsifier: a refusal token in the ledger with no grep hit in the current
ash_surface tree.
