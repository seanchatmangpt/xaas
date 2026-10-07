# W859 — Lane Receipt: Consolidated Typed-Gap Register

Lane W859, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf6`.
No commit made (per dispatch); no build root created; coordinator owns integration.

## Deliverable

- `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md` — 42-row consolidated typed-gap
  register. Every row cites a disclosing receipt and a status-bearing receipt.

## Method (recall + verification)

1. `grep -n -E 'UNSUPPORTED\(|GAP-[0-9]|OPEN_GAP|typed gap|TYPED-OPEN'` over
   `docs/sjira/v26.10.6/plans/w*.md` (274 raw hits) to enumerate disclosure surfaces.
2. Targeted recall per the dispatch's completeness list (W665, W674, W722, W729, W731, W745,
   W750-G2, W763, W765, W770, W793, W796, W799, W804/W819/W849 backlog items, W824, W811,
   W784, W650c's 49.3) — every named receipt read in full-tail (status section).
3. **Status re-derivation, not transcription**: each disclosing receipt's tail/status section
   read for current standing; cross-repair receipts located and verified (W780 for W763-G1,
   W809 for W796-G2, W676 for W650c OPEN_GAP-1/2, W659d for W650c OPEN_GAP-4).
4. Count verification by real grep on the written file: 43 table lines = 1 header + 42 gap
   rows; `| OPEN |` ×36, `| REPAIRED |` ×4, `| TYPED-OPEN |` ×2 (sum = 42). One early
   totals error (37 OPEN / 43 rows) was caught by the count grep and corrected to
   36 OPEN / 42 rows.

## Status totals (verified by grep on the deliverable)

- OPEN: 36
- REPAIRED: 4 (W763-G1→W780; W796-G2→W809; W650c OPEN_GAP-1/2→W676; W650c OPEN_GAP-4→W659d)
- TYPED-OPEN: 2 (W811 test-scope boundary; EU-AI-Act 49.3 corpus open-gap row, registered by W815/W779)
- Total: 42 rows across 22 disclosing receipts.

## Standing

- Register: ALIVE as a documentation artifact (every row cites two receipts; counts grep-verified
  on the written file; no lib/test change, no build root). The statuses are receipt-derived
  as of HEAD `a0723bf6` tree state; a future repairing receipt invalidates the row, per the
  register header's falsifier.
- Not committed; coordinator owns the integration commit.

## Falsifier

Any row whose two cited receipts do not contain the quoted status fact, or a later repair
receipt landing after HEAD `a0723bf6` without a register row update, flips the register to
STALE — re-run the method (grep + receipt-tail read) to refresh.

## See also

- `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md` (the register = the receipt)
