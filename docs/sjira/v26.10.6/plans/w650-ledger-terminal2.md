# W650 — Terminal-2 ledger update (post-deepening/flips)

Lane W650, EU-AI-Act wave, 2026-10-06. Repo `/Users/sac/xaas` @
`feat/playwright-surface` (one canonical checkout). Writes: this receipt and an
append to `docs/cro/artifacts/implementation-wave-ledger.md` only.

## Task

Poll the final wave receipts, then append "## Terminal-2 (post-deepening/flips)"
to the implementation wave ledger: final per-lane standing (W500–W651), the
open-gap trajectory with aggregation citations, and the terminal inventory of
remaining honest gaps.

## Poll log (receipts checked on disk, docs/sjira/v26.10.6/plans/)

| receipt | present | key verdict |
|---|---|---|
| w546-os18-fix.md | yes | `checkpoint_external/2` tautology fixed; witness flipped, mutant KILLED; corpus run-log placeholder stands |
| w547-gap-flips.md | yes | 13 flips (12 EVIDENCED, 1 N/A); suite 37 → 24 |
| w616-deepening.md | yes | 22 Title I–II bodies deepened to real `admit/1` calls + near-miss controls |
| w623-title-iii-deepening.md | yes | Title III deepened via 8 real-call kinds |
| w626c-deepening-iv-xiii.md | yes | 14 lines deepened/repaired; foreign-lane release_audit.ex compile blocker repaired (disclosed) |
| w625c-art73-flips.md | yes | 9 Art-73 flips (8 EVIDENCED, 73.9 N/A); file census 14 → 5; 471 passed / 5 excluded |
| w550-counterfactual-harness.md | yes | 17-test Pearl-3-step harness, 17 passed |
| w551-counterfactual-kill-ledger.md | yes | **PENDING**: all 6 mutants + KillScore unfilled → lane PARTIAL |
| w624-counterfactual-extension.md | yes | +7 rows; Art 9(2)(a) honestly NOT_RUN (cross-repo) |
| w607-349-41-closures.md | yes | 3.49.a–d EVIDENCED; 4.1 kept OPEN (`GAP(NO_AI_LITERACY_SURFACE)`) |
| w525b-title-i.md | yes | Title I generator (Arts 1–4) |
| w531-title-ii-corpus-loop.md | yes | 26/26 Title II lines covered |
| w534-title-iii-restructure.md | yes | fixed include-over-exclude defect (91 resurrected gap tests) |
| w535-title-iii-remaining-gaps.md | yes | 13 EVIDENCED + 23 NOT_APPLICABLE for Arts 8/10/11/15/26/27 |
| w606-corpus-coverage-audit-2.md | yes | 1068 corpus ids, 1072 generated, 24 failures all OPEN_GAP-by-design, 0 uncovered |
| w611-corpus-coverage-final.md | yes | coverage COMPLETE: 0 uncovered, 0 id-level duplicates; 5 real-behavior failures flagged to coordinator |
| w630-totality-fix.md | yes | 4 fuzz escapes closed (RobustMargin / DatasetAdmission / EuAiActAdmission); gates total |

All named receipts landed; no lane BLOCKED at terminal.

## What the ledger append contains

- Final per-lane standing table W500–W651: **ALIVE 42 lane-groups (≈57 lanes),
  PARTIAL 4 (W511, W512, W546, W551 — disclosed unfilled sections), BLOCKED 0.**
- Open-gap trajectory with citations: **91 → 37 → 24 → 19 → 15 → 10**
  (w534 defect → w543 aggregation-2 → w547 flips → w605 aggregation-3 →
  w625c Art-73 flips → w622 aggregation-4, the current count).
- Terminal inventory of the **10 remaining typed open gaps**: 4.1, 8.1,
  27.1.b, 27.1.e, 27.1.f, 74.12, 74.13.a, 74.13.b, 86.2, 86.3.
- Resolution status of the task's named candidates: **14.4.b RESOLVED**
  (W547/W539 + W623/W624 deepening); **73.x RESOLVED with typed caveat**
  (EVIDENCED, endpoints `:OPEN`, `PREPARED_NOT_TRANSMITTED`, 73.9 N/A);
  **86.2/86.3, 4.1, 8.1, 74.x, FRIA schedule fields — OPEN.**
- Carry-forward updated (items 1–4 unchanged; added #5: fill-or-retire W551's
  mutation ledger; #6: the 10-gap future-work list).

## Verification

- Every polled receipt read from disk (real `ls` + `head`/`sed`/`tail` output
  above in session transcript; receipt counts cross-checked against the
  W622 aggregation-4 census, which the terminal section cites).
- Ledger diff verified on disk after edit: Terminal-2 section present at
  lines ~154–280; two transcription-garbled table rows caught and repaired
  in-place immediately after the append (27.1.e row, 86.2 row, separator row).

## Standing

ALIVE (poll + append executed against real receipts on the exact tree).
Falsifier: a named receipt absent from `docs/sjira/v26.10.6/plans/`, or a
ledger count contradicting w622-euaia-aggregation-4.md, flips this to
residual.
