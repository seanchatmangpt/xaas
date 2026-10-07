# W978 Receipt — capability_liveness_regressions.ex Syntax Repair

Lane: W978, xaas v26.10.6 campaign, branch feat/playwright-surface @ fab56ae1
Scope: lib/xaas/operations/capability_liveness_regressions.ex only

## Finding: no repair required

Task input (from W946b run-3 OBSERVED-BLOCKED) claimed `:83 "unexpected reserved
word: end"`. On read, the file at mtime 2026-10-07 07:39 is a complete, balanced
82-line module (83 lines incl. trailing newline): the W968c/SPEC-14
upsert-overwrite repair (`in_place_regression/1` + `cross_subject_regression/3`)
is fully present with all delimiters closed. A sibling lane completed the
interrupted edit before W978 picked it up; the :83 error was already gone.

`git diff HEAD -- <file>` shows only the intended W968c delta (guarded-case
refactor into the two helper defps), no truncation or duplication.

## Verification (real runs, this lane, MIX_BUILD_ROOT=_build-laneW978)

1. Parse gate: `elixir -e 'Code.string_to_quoted!(...)'` -> PARSE_OK
2. Full `mix compile` -> EXIT=0 ("Generated xaas app")
3. Courts:
   - capability_liveness_regressions_property_test +
     capability_liveness_receipt_check_regressions_test +
     capability_liveness_receipt_test (W768 status-gate file):
     `Result: 11 passed, 1 excluded` — green.
   - capability_liveness_deepening_test: 21/22 passed, 1 excluded, **1 failed**
     (W968c "previous_status written by :ingest and not forgeable") —
     PRE-EXISTING at HEAD fd471722, out of lane scope: the resource
     (`capability_liveness_receipt.ex:174`, unchanged worktree-vs-HEAD) does not
     accept `previous_status` on :ingest while the committed test does. That is
     the sibling receipt-resource lane's in-flight surface, not regressions.ex.

## Transport failures observed

- Mid-run, a sibling lane broke `lib/xaas/bridges/graphlaw.ex:161` (missing
  `end`), transiently failing the second test batch; it self-healed on retry
  ~2 min later. Lane did not touch that file.

## Standing

- W978 (regressions.ex syntax): ALIVE — verified on exact subject
  fab56ae1 + worktree regressions.ex (0 edits by this lane).
- W968c upsert-overwrite court (deepening W968c test): BLOCKED
  (pre-existing, receipt-resource accept-list surface).
- Lane build root `_build-laneW978` deleted post-verification.

Standing: ALIVE (no-edit verification receipt).
