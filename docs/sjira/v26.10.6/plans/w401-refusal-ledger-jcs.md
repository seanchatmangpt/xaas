# W401 — CRO Stage-3 refusal-ledger JCS export (2026-10-06, lane W401)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface` @ `d1db2b03`. Backfill
stub: the artifact landed on disk before its plan receipt; evidence is the
artifact itself.

Artifact: `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` +
`docs/cro/artifacts/refusal-ledger-v26.10.6.README.md` (CRO-loop Stage-3).
Evidence: 62/62 typed `REFUSED_*` tokens exported as RFC 8785-style canonical
JSON (sorted keys, no whitespace); real `json.load` parse plus double
canonical round-trip byte-compared STABLE; per-token coverage with the
w236-refusal-capstone corpus and delta-0 recount (w202) as upstream sources;
scope note: in-repo pinned conformance court corpus, not the official A2A
TCK.

Falsifier: any token in the JCS ledger absent from
`docs/sjira/v26.10.6/plans/w236-refusal-capstone.md` voids the coverage row.
