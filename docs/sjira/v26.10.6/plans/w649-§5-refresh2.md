# W649 — §5 refresh-2 (closure plan DoD table)

Lane W649, 2026-10-06, repo `/Users/sac/xaas` @ `feat/playwright-surface` (one
canonical checkout; no commit — coordinator owns integration).

## Scope honored

Only `_CLOSURE_PLAN.md` §5 table rows + trailing delta note edited; this
receipt. No lib/test edits.

## Receipts `test -f`-verified before citation

All under `plans/`: w546-os18-fix.md, w547-gap-flips.md,
w623-title-iii-deepening.md, w626c-deepening-iv-xiii.md, w616-deepening.md,
w625c-art73-flips.md, w550-counterfactual-harness.md, w624-counterfactual-extension.md,
w624b-harness-repair.md, w551-counterfactual-kill-ledger.md,
w291-ash-pplan-verdict.md, w607-349-41-closures.md — all EXIST.
w551's ledger verdicts are still PENDING inside the receipt — cited as
in-flight only, never as evidence.

## Diff summary (3 rows + delta note)

1. **DoD 3 refusal coverage — LANDED (extended)**: added OS-18 FIXED via
   w546 (tautology → LIVE clause, forged foreign admission pairs refused
   `:external_admission_identity_mismatch`, mutant-killed, falsifier replayed;
   contention-free castle rerun 19/19 disclosed as open); W547 consolidation
   flips; deepening trio w616 (22 bodies) / w623 (54 lines) / w626c (14 lines);
   Art 73 flips w607 (3.49-family ×5) + w625c (×9: 8 EVIDENCED, 73.9
   NOT_APPLICABLE typed, open-gap census 24→15); counterfactual harness
   w550/w624/w624b **23/23 green ×2** (title_ii 40/40). Removed the stale
   "no w546 receipt on disk" caveat. w551 kill ledger marked in-flight.
2. **DoD 5 verify ladder — ash_pplan PENDING(W291) → LANDED**: w291 receipt
   @ ash_pplan 414a393 (fix/ggen-verify-header) now on disk; patches verified
   on both files; **narrow gate GREEN (decisive)**; full suite run 1 exit 0
   but tail contaminated (cap-induced) — no full-suite verdict claimed;
   P0-3 pins warning → folds into coordinator commit gates. Added
   w635-ash-pplan-airo.md as an on-disk cross-reference.
3. **DoD 7 no new features — MET, manifest gap flagged**: UNTRACED 0 stands
   for the v3-manifest era; AIRo wave (w600…w639) and counterfactual wave
   (w550/w624/w624b/w551) landed after manifest v3 → **v4 addendum required**
   for the W500/W600-series files before DoD 4 commit gates close.

DoD 1, 2, 4, 6 rows untouched (W548 rows still accurate; DoD 4 remains
coordinator-gated, honest).

## Per-DoD final verdicts

| DoD | verdict |
|---|---|
| 1 tests green | LANDED (quiescent re-run pending, coordinator-scheduled) |
| 2 strict flags | LANDED (local legs) + CI advisory (operator promotion) |
| 3 refusal coverage | LANDED (w551 mutant verdicts + quiet castle rerun open, in-flight) |
| 4 clean tree | PENDING (coordinator) |
| 5 verify ladder | LANDED — browser / CLI / ash_pplan all now evidenced (P0-3 pins → commit-gate) |
| 6 frontier non-UNKNOWN | LANDED (wasm4pm CI confirm post-commit, folds into DoD 4) |
| 7 no new features | MET (manifest v4 addendum for W500/W600-series flagged to coordinator) |
