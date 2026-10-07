# W13 — Plug & Actuation Refusal Negative Tests

- Lane: W13
- Subject: see _LANES roster
- Date: 2026-10-06
- Note: backfilled by coordinator from lane completion report

## What landed

- `test/xaas_web/plugs/require_internal_api_token_test.exs` — 7 tests:
  no-header 401; bad-bearer 401; unset-env+no-header 503; unset+wrong 503;
  empty-bearer 401; basic-scheme 401; happy-path 200 control.
  `assigns[:current_org]` never set on refusals.
- `test/xaas/actuation_refusal_negative_test.exs` — 4 tests:
  subject_id_required + 3 external mismatch atoms, exact tuples,
  pre==post state.

## Gate output (verbatim as reported)

17 passed, exit 0.

## Disclosures

- subject_id_required atom fails receipt-seal validation → rolls back
  (pinned real contract).
- external_admission_identity_mismatch structurally unreachable.
