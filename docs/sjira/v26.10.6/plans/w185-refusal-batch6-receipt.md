# W185 — batch6/r2rml refusal fixtures (standalone receipt)

*Filed by coordinator 2026-10-06 from executed lineage; supersedes the
appendix-only state flagged in _CLOSURE_PLAN.md DoD 3 and _CLOSURE_RECEIPT.md.*
Subject: /Users/sac/xaas @ feat/playwright-surface @ `d1db2b03179975213c14663b9dbd86b5ac2a14cf`.

## What landed
- `test/xaas/castle_refusal_negative_batch6_test.exs` — 18 tests: 13 castle
  outer-intent/receipt verification gate mutations (INTENT_NOT_EXECUTING,
  RESOURCE/ACTION/SUBJECT/PROJECTION mismatches, PROJECTION_DRIFT,
  IDEMPOTENCY_MISMATCH, RECEIPT_* family) + REQUIRED_FIELD admission/CLI paths.
- `test/xaas/r2rml_refusal_test.exs` — 2 tests: NON_UNIQUE_SEMANTIC_IDENTITY
  + UNKNOWN_ATTRIBUTE (the latter reclassified structurally unreachable by
  call-graph argument, w185/w321 — witness retained).

## Executed verdicts (lineage)
- w208 combined gate: 20/20 green (batch6 + r2rml).
- w236 consolidated capstone: 86/0 (12 files, batch1–6 + r2rml + vkg +
  actuation + plug + endpoint).
- w312 post-format re-run: 62/0. w263b re-run: 86/0.
- w449/w414-era: plug file now 9 tests (w414 killer added); corpus at final
  tree re-adjudicated by w398b (in flight, isolate-twice protocol).
- Authoritative token recount (w202, re-run in w318's contract and
  w439's replay validation): delta 0, coverage 62/62 = 100%.

## Standing
ALIVE — DoD 3's last receipt-availability gap closed. Remaining corpus
verification: w398b (final-tree re-run, contention-classified).
