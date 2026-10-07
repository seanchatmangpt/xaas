# W950 — register W674-GAP-2 flip (receipt)

- **Lane**: W950, v26.10.6 campaign, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`. No commit (per lane contract). No build root.
- **Task**: W928's receipt (`w928-gymact-hygiene.md`) landed the hygiene fix that
  held W674-GAP-2 open; flip the register row and recompute totals.

## Pre-edit disk state (read, not transcribed)

Row 21 of `w859-typed-gap-register.md` held `OPEN` with the w900 staging
annotation (typed-refusal fix staged; suite 7/11; row stays OPEN pending test-side
hygiene fix). Totals line read 49 rows = 31 OPEN + 16 REPAIRED + 2 TYPED-OPEN,
grep-verified pre-edit: 31 OPEN / 16 REPAIRED / 2 TYPED-OPEN / 1 header row.

## Tree verification

- `test/xaas/operations/gymact_surface_deepening_test.exs`: w928's helpers present
  (12 references to `sealed_intent!`/`sealed_receipt!`); line 336 carries the
  "never hd() an unfiltered read" hygiene comment; no unfiltered
  `Ash.read!(ActuationReceipt)` reads remain.
- `lib/xaas/operations/gymact_surface.ex:246,253`: w900's typed refusals
  `Refusal.new(:episode_id_required, ...)` / `Refusal.new(:cut_required, ...)`
  confirmed on tree.
- `w928-gymact-hygiene.md` present on disk; its court: 11/11 passed ×2
  consecutive runs (run A 0.7s, run B confirmation), exit 0, no production code
  touched. Not re-executed this lane (register flip cites w928's landed court).

## Row before → after

- **Before**: `| W674-GAP-2: actuate/4 without :episode_id/:cut raises raw
  WithClauseError instead of typed refusal | w674-gymact-deepening.md |
  GymactSurface.do_and_seal/2 | OPEN | w674 (disclosure) + w900-batch2 (staging;
  suite 7/11; row stays OPEN pending one-line test-side hygiene fix) |`
- **After**: `REPAIRED`, triple-cited: w674-gymact-deepening.md (original
  disclosure) + w900-batch2-repairs.md (staging: typed
  `:episode_id_required`/`:cut_required` refusals, confirmed on tree) +
  w928-gymact-hygiene.md (hygiene court: 8 unfiltered `hd()` reads replaced with
  per-test key/intent-filtered reads, 11/11 ×2, exit 0).

## New totals (grep-verified post-edit)

- 49 rows = **30 OPEN + 17 REPAIRED + 2 TYPED-OPEN** (awk field-5 count over the
  register table: 30/17/2 + 1 header).
- REPAIRED enumeration extended with `W674-GAP-2 → w900 staging + w928 hygiene
  court`; OPEN enumeration shrunk by W674-GAP-2 (W674-GAP-1 remains OPEN).
- Update-log entry appended: "W950 update (2026-10-07): 1 flip — W674-GAP-2
  OPEN → REPAIRED, triple-cited ... Totals grep-verified."

## Standing

ALIVE for the register flip: row wording and totals on disk match w928's landed
receipt and the live tree (helpers + typed refusals grepped this lane). The
underlying capability (typed refusal + non-pollutable durable-seal court) is
witnessed by w928's court; this lane is bookkeeping only — no code, no build
root, no commit. Register sweep history (W923/W944/W943b/W943c/W946c) preserved
intact; W674-GAP-1 stays OPEN (no repairing receipt).
