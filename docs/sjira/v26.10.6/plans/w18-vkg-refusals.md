# W18 — VKG Refusal Negative Tests

- Lane: W18
- Subject: see _LANES roster
- Date: 2026-10-06
- Note: backfilled by coordinator from lane completion report

## What landed

- `test/xaas/semantics/vkg_refusal_negative_test.exs` — 3/3 passing:
  WITNESS (tampered row_count); REPLAY (tampered result_sha256);
  EMPTY_CATALOG (unreachable — shielded by Manifest.load_all refusal;
  pinned REFUSED_VKG_MANIFEST as the reachable edge).
- Seller un-skip: reverted (assertion string drift); later landed by
  coordinator with parenthesized syntax.

## Gate output (verbatim as reported)

3/3 passed.

## Disclosures

- EMPTY_CATALOG is not directly reachable; the manifest-load refusal
  edge is the pinned surface.
- Seller un-skip initially failed on assertion string drift and was
  reverted before the coordinator's parenthesized-syntax version landed.
