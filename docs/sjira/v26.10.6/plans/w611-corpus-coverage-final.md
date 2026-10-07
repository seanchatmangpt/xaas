# W611 — EU AI Act Corpus Coverage FINAL Audit (post-W608 + W607)

Lane: W611 (final coverage audit). Subject: `xaas @ feat/playwright-surface`,
working tree 2026-10-06. Only write: this receipt.

## Prior state

* W608 receipt (`w608-art56-boundary.md`) observed present and complete
  before the run: Art. 56 (15 lines) closed at typed NOT_APPLICABLE via
  the Title IV+V generator range `28..55` → `28..56`. No polling needed —
  the receipt was already on disk at lane start.
* W606 (`w606-corpus-coverage-audit-2.md`) baseline: 1068 corpus ids,
  1072 generated, 24 failures all OPEN_GAP-by-design, 0 uncovered, 5
  documented intentional Title II synthetic extras.

## Method (same as W606/W527)

1. Corpus ground truth: `docs/eu_ai_act/corpus.json` → 1068 unique
   `line_id`s (0 duplicates).
2. Real suite trace under the pinned toolchain (asdf shims prepended),
   private build root `_build-laneW611`:

   ```
   PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW611 mix test test/eu_ai_act --include eu_ai_act --trace
   ```

3. Set-diff of trace-extracted test ids vs the 1068 corpus ids.

## Transport failures (recorded, not repaired by this lane)

Run 1 hit a fresh-build compile error in
`lib/xaas/semantics/airo_risk_mapping.ex:201` (SyntaxError, `if` inside
`#{}` without parens). The file **does not exist on disk now and never
matched the repo tree** — another lane was concurrently mutating the
shared tree outside its lane contract mid-compile. Recorded as typed
transport failure; run 2 against the settled tree compiled clean.

## Result

Full run: **1104 tests generated, 1079 passed, 25 failed** (exit 1,
expected — OPEN_GAP tests flunk by design).

| set | count |
|---|---|
| corpus line_ids | 1068 |
| generated tests | 1104 |
| passed | 1079 |
| failed | 25 |
| unique trace ids extracted | 1074 |
| UNCOVERED (corpus − generated) | **0** |
| EXTRA (generated − corpus) | 6 |

* **UNCOVERED = 0** — every one of the 1068 corpus line_ids has a
  generated, executed test. W608's 15 Art. 56 lines are present in the
  trace (all NOT_APPLICABLE, e.g. `56.1, 56.2.a–d, 56.3, 56.9.s2`).
* **EXTRA = 6**, all the documented intentional W522 synthetic Title II
  layer: `5.1.a-manipulative`, `5.1.a-vulnerability`, `5.1.g-h`,
  `5.catch-all`, `5.live-integration`, `5.structural-gate` (W606 counted
  5; the extra `5.1.g-h` is the same synthetic partition family). Not
  corpus misses and not corpus coverage gaps.
* **Duplicates**: 0 at the id level. `--trace` prints each test name on
  both the start and completion lines, so raw id occurrences (3116)
  exceed unique ids (1074) — a trace-format artifact, not suite
  duplication.

## Failures (all 25)

By design OPEN_GAP flunks (21 id-tagged) plus 5 real-behavior tests:

* 16 × Title VI–XIII OPEN_GAP (Art. 73.x/74.x/86.x serious-incident and
  right-to-explanation rows),
* 4 × Title III OPEN_GAP (`8.1`, `27.1.b`, `27.1.e`, `27.1.f`),
* 1 × Title I OPEN_GAP (`4.1` — W607's lane, still OPEN_GAP by design),
* 4 × `Xaas.EuAiAct.CounterfactualTest` (Art. 5(1)(b/c/d/e), Art. 12)
  and 1 × `EUAI-ACT 5.live-integration` — real-behavior tests inside the
  same suite, outside the corpus-id set. Their status vs W606's "24 all
  OPEN_GAP by design" is flagged for the coordinator: W606's count did
  not itemize these 5, and W607's 3.49/4.1 lane touched the Title I
  surface. Not a coverage regression (corpus coverage unaffected), but
  their flunk status is not "OPEN_GAP by design" in the same typed sense
  — they are real-behavior assertions currently failing.

## Verdict

**COMPLETE** for corpus coverage: 0 uncovered, 0 id-level duplicates,
extra = the documented intentional Title II synthetic layer only. The
EU-AI-Act loop's terminal coverage condition holds as of this trace.

Falsifier for this verdict: any future corpus.json line added without a
corresponding generated test flips this to residual.

## Standing

Receipt: ALIVE (real trace, exact commands, real set-diff). Art. 56
boundary receipt W608 verified present and consumed. Residual for the
coordinator only: the 5 real-behavior failures
(CounterfactualTest ×4 + 5.live-integration) and W607's 4.1 OPEN_GAP.
