# W910 — W905 Spec Registration Receipt

- Lane W910, xaas v26.10.6, repo `/Users/sac/xaas` @ `feat/playwright-surface` HEAD `a0723bf6`.
- Date: 2026-10-07. Doc-only; no code, no build root, no commit.
- Task: register the W905 DESIGN-class spec backlog against the W891 triage.

## Registration

- `docs/sjira/v26.10.6/plans/w905-design-gap-specs.md` exists (16,257 bytes, mtime
  2026-10-07 06:15) and covers all 18 DESIGN rows from `w891-gap-triage.md`:
  2 S / 12 M / 4 L, with row ids SPEC-04, 07, 08, 09, 10, 14, 16, 17, 18, 20, 21, 24,
  26, 27, 30, 31, 32, 34 — exactly matching the w891 DESIGN row set (rows 4, 7, 8, 9,
  10, 14, 16, 17, 18, 20, 21, 24, 26, 27, 30, 31, 32, 34). Row 23's drift flag
  (W793 4-gap split-and-reverify) is carried into SPEC-24's sequencing note.
- Pointer appended to `w891-gap-triage.md` (footer): "DESIGN-class rows spec'd by
  w905-design-gap-specs.md (2026-10-07) — registered by w910-spec-registration.md."

## Spot-check (2 of 18)

- **SPEC-04 (W722-GAP-2, org auth plug)** vs `w722-governance-deepening.md`: row id
  matches the disclosing receipt's GAP-2; the receipt's `X-Org-Id` caller-asserted
  limitation and `ResolveOrgActor` demotion surface are real (grep hit in the receipt);
  named paths verified on disk: `lib/xaas_web/router.ex`,
  `test/xaas/governance/multitenant_approval_deepening_test.exs`. PASS.
- **SPEC-27 (W799-GAP-1, ledger reversal action)** vs `w799-reversal-deepening.md`:
  row id matches; the receipt confirms zero `:refund|:reverse|:undo` in
  `lib/xaas/ledger/` (grep evidence quoted in receipt), the sufficiency-accident
  double-reversal shape, the W746 `filter(expr(is_nil(approved_by)))` guard class, and
  the named test `test/xaas/ledger/reversal_deepening_test.exs` exists on disk.
  `lib/xaas/ledger/transfer.ex` exists. PASS.

## Standing

- PARTIAL_ALIVE — registration is a doc-only transition; the spec backlog is ALIVE as a
  document on the exact subject (both spot-checked rows verified against their
  disclosing receipts and on-disk paths). No register-row status changed; the 18 rows
  remain OPEN until their implementation waves land and are witnessed by real runs.
- Falsifier: any of the 18 spec rows whose named file paths or disclosing-receipt claims
  are absent on a future HEAD re-read — re-verify before opening the implementation lane.
