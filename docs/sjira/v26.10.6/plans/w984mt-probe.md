# W984mt — W984me Findings Closure: Procedural Fallback Court + Independent Ranking Oracle

Lane: W984mt · Date: 2026-10-08 · Branch `feat/playwright-surface` (no branch switch,
no commits, no stash). Method per `w984ek/ha/jp/lc/me-probe.md` (FILE-SWAP baseline:
`cp` snapshots in `/tmp/w984mt/`, one surgical lib mutation at a time, targeted court
run, `cmp`-verified byte-identical restore, post-restore green confirmation).

## Findings closed

- (a) `lib/xaas/library/ranker.ex`'s ~160-line procedural fallback was masked by the
  reactor path — every procedural-only mutant survived all courts (W984me M1).
- (b) `expected_ranking!/2` in `test/xaas_web/next_read_live_deepening_test.exs` is a
  shared-oracle tautology (ranker asserted against itself; W984me M4 single-leg
  survivor against that court alone).

## Method

New court `test/xaas/library/ranker_fallback_court_w984mt_test.exs` (12 tests), all
real Postgres via sandbox, real Ash actions, zero mocks.

Fallback forcing, no mocks: a non-integer `student_grade` ("six") fails the REAL Ash
argument cast on `Curation.active_for_grade`'s `grade_level` (`:integer`,
allow_nil?: false) inside `RecommendationPipelineReactor`'s `:get_active_curations`
read step → `Reactor.run/3` returns `{:error, _}` → `rank_recommendations/3` executes
`rank_recommendations_procedural/2`. A differential-gate test first proves the
integer-grade control runs the reactor and the "six" call produces the same factor
semantics via the fallback. Not a mock, not a stub: the real Ash input-validation
failure branches real code.

Courts: curation boost, sort order (strictly-decreasing scores + designed distinct
scores), acceptance boost (0.75 vs 0.5 collab pins), weight magnitude+sign
(+1.0/-1.0 curation weight flips the curated book's position — proves multiplication,
not membership), exclude_read, grade_fit/diversity exact pins, tie scores, plus an
independent hand-computed oracle describe (finding b): twin catalogs holding every
factor at parity except the factor under test, expected order derived by hand from
the documented factor semantics and `Config.weights/1` — grade_fit (reactor linear
decay 1.0 vs 0.0), curation (0.09 swing), acceptance (0.085 swing), availability
(0.10 swing).

## Mutation re-verification matrix (MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW984mt)

Baseline: 12/12 passed, exit 0. Every leg: one surgical lib mutation, run the
W984mt court, `cmp`-verified byte-identical restore. Post-restore sweep: 12/12.

| # | Mutated surface | Mutation | Result | Verdict |
|---|---|---|---|---|
| R1 (=W984me M1) | `ranker.ex` procedural `curation_score` | → `0.0` unconditionally | 8/12 RED | **KILLED** (was SURVIVED under all W984me courts) |
| R2 | `ranker.ex` procedural sort | `Enum.sort_by(..., :desc)` → `:asc` | 8/12 RED | **KILLED** |
| R3 | `ranker.ex` procedural acceptance boost | `min(1.0, base_score + 0.25)` → `base_score` | 11/12 RED | **KILLED** |
| R4 | `ranker.ex` procedural weighting | `current_weights.curation * curation_score` → `curation_score` | 11/12 RED | **KILLED** |
| R5 (=W984me M4) | `recommendation_pipeline_reactor.ex` `:rank_candidates` sort | `:desc` → `:asc` | 8/12 RED | **KILLED** by the W984mt court (was SURVIVED vs live deepening court alone) |
| R5-control | same M4 mutant | same | 4 passed | SURVIVES the old `next_read_live_deepening_test.exs` alone — exact confirmation of W984me's tautology finding; (b) is closed by the new independent oracle, not by editing the old court |

Totals: 5 mutant legs + 1 control — 5 KILLED by the W984mt court; the M4 tautology
reproduced exactly on the old court. No survivor against the new courts. Every kill
is a typed value/order pin (factor value, exact subset ranking, sign-flip position,
0.75/0.5 collab pins), not crash-only.

## Tree cleanliness

Restores `cmp`-verified byte-identical (ranker.ex, recommendation_pipeline_reactor.ex).
Final sweep: W984mt court 12/12; siblings `next_read_test` + `ranker_test` +
`next_read_live_deepening` = 35 passed. Mock gate `[]`. No commit made. No lib/
surface left modified vs HEAD.

## Standing

**ALIVE** — both W984me findings closed on the exact subjects, this lane, branch
feat/playwright-surface: (a) procedural fallback now observed executing and courted
(R1–R4 kills); (b) independent hand-computed ranking oracle in place, and the M4
sort mutant is now killed by the W984mt court while still surviving the old
shared-oracle court alone.

## Replay

```bash
cd /Users/sac/xaas
export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984mt
mix test test/xaas/library/ranker_fallback_court_w984mt_test.exs   # 12 passed
# apply one mutation from the matrix (cp-snapshot file swap), expect RED
# restore from /tmp/w984mt/*.orig, cmp-verify byte-identical, expect green
```

## Cleanup

`rm -rf _build-laneW984mt` attempted; result recorded in the lane report.
