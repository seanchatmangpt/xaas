# W971b — Triage-close receipt (2026-10-07)

## Identity

- Subject: uncommitted working tree of `/Users/sac/xaas` @ `feat/playwright-surface` (no commit made, per lane instruction).
- Lane: W971b, xaas v26.10.6 campaign. Writes confined to
  `docs/sjira/v26.10.6/plans/w891-gap-triage.md` (footer append) +
  this receipt. No build root created.

## O / O*

- W967 reconcile: 13/35 closed, 5 unflipped (W665 / W729-lifecycle / W731-path /
  W729-idem / row 29); W968b flipped those 5; W971 audit to 17/31/2 on 50 rows —
  admitted from disk files (`w967-triage-final.md`,
  `w968b-register-final-flips.md`, `w971-open-recount.md`).
- Register ground truth re-derived from `w859-typed-gap-register.md` on disk:
  `grep -oE '\| (OPEN|REPAIRED|TYPED-OPEN) \|' | sort | uniq -c` →
  17 OPEN / 31 REPAIRED / 2 TYPED-OPEN (50 rows). Matches W971 figure.
- `w968c-*.md`, `w969b-*.md`, `w969c-*.md`: absent on disk (null_glob loop,
  0 files). Wave receipts not landed → waves 1-3 standing UNKNOWN.

## μ / diff

- Appended "Triage-close footer (W971b, 2026-10-07)" to
  `docs/sjira/v26.10.6/plans/w891-gap-triage.md`. Handwritten prose only;
  no generated surfaces touched.

## Footer content (all facts file-derived)

1. CHEAP-REPAIR disposition complete: W665 → w897 row 1; W729 lifecycle → w897
   row 5; W729 idem → already on HEAD via W746 (w897 drift note); W731 → w897
   row 11; all four flipped by w968b. Row 29/W804 confirmed OPERATOR, stays
   OPEN (direct-DDL replay hazard annotated in register row 50).
2. 18 DESIGN rows spec'd in `w905-design-gap-specs.md`; waves 1-3 (w968c /
   w969b / w969c) in flight, receipts absent on disk — wave standing UNKNOWN.
3. Final totals grep-verified: 17 OPEN / 31 REPAIRED / 2 TYPED-OPEN on 50 rows.
4. Remaining-OPEN dispositions: DESIGN-pending 14 (W722-g2, W729 multitenancy,
   W729 atomic_update, W731 limits-enforcement, W750-G2, W765 GAP-D, W770
   retention, W793 cross-ref, W796-G3, W799 reversal, graphql mount + coverage
   (2), W824, W849 backlog-2); OPERATOR 2 (W804, W902); backlog-deferred
   DESIGN-class 1 (W784 TOFU); TYPED-OPEN 2 (W811 scope boundary + 49.3 corpus
   row).

## Commands / exits

- `grep -cE '^\| W[0-9]' w859-typed-gap-register.md` → 36 (row ids, not the
  50-row status count; superseded by the status grep below) — exit 0.
- `grep -oE '\| (OPEN|REPAIRED|TYPED-OPEN) \|' w859-typed-gap-register.md | sort | uniq -c`
  → 17/31/2 — exit 0.
- `setopt null_glob; for f in w968c-*.md w969b-*.md w969c-*.md; do echo present: $f; done`
  → no output (all absent) — exit 0.
- Append heredoc to w891-gap-triage.md — exit 0; verified appended (heading
  present at end of file).

## Verification ladder

Narrow (grep on-disk evidence) → file-append + re-read confirmation. No build,
no tests touched — documentation-only lane; no court required.

## Standing

- Triage standing: **CLOSED** — every CHEAP-REPAIR row repaired (receipt-cited)
  or confirmed DESIGN/OPERATOR; footer cites only on-disk facts.
- Waves 1-3: UNKNOWN (receipts not landed).
- Register: PARTIAL_ALIVE (17/31/2, grep-verified).
- Receipt: this file; replay = re-run the two greps + `ls` of wave receipt
  paths against the register and plans dir.

## Falsifiers

- F1: re-run the status grep on w859 — if totals ≠ 17/31/2, this footer is stale.
- F2: `ls docs/sjira/v26.10.6/plans/w968c-*.md w969b-*.md w969c-*.md` — any
  present file invalidates the "receipts not landed" claim (footer would then
  under-report wave standing).
