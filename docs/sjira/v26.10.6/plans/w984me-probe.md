# W984me — Mutation Non-Vacuity Audit #10 over W984lh Next-Read Oracle + W984kk 204-Silence Fix

Lane: W984me · Date: 2026-10-08 · Branch `feat/playwright-surface` (no branch switch,
no commits, no stash). Method held exactly per `w984ek/ha/iy/jp/lc-probe.md` (FILE-SWAP
baseline: `cp` snapshots in `/tmp/w984me/`, one surgical lib mutation at a time, targeted
court run, `cmp`-verified byte-identical restore, post-restore green confirmation).
Compound-leg convention per W984ha/jp/lc applied where guards could mask (M1c, M4c, N2).

Subjects:
- W984lh's next-read oracle repairs: `test/xaas_web/next_read_live_deepening_test.exs`
  (live-surface-vs-ranker oracle) + `test/xaas/library/next_read_test.exs` (6-factor
  composite court), over the ranking surfaces (started on `lib/xaas/library/ranker.ex`,
  routed to the surfaces the live path actually executes — see Key Structural Finding).
- W984kk's 204-silence fix: `lib/xaas_web/controllers/execution_fabric_controller.ex`
  `mcp_typed/2` `{:ok, :notification}` arm, court
  `test/xaas_web/controllers/fabric_court_w984js_test.exs`.

Gates: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984me`.
Fresh lane-root compile: EXIT=0. Baselines (pre-mutation): next_read 14 passed,
live deepening 4 passed, fabric court 10 passed — all EXIT=0.

## Key structural finding

The live next-read path runs `Ranker.rank_recommendations/3` →
`RecommendationPipelineReactor` → `Steps.ScoreBook` only when the reactor succeeds;
`ranker.ex`'s ~160-line procedural fallback (`rank_recommendations_procedural/2`,
`compute_collab_score/3`, procedural `curation_score`) is dead under every current
court — every procedural-only mutant survives. Effective mutants must target the
reactor/`ScoreBook` surface. Headline finding: roughly half of `ranker.ex` is
unobservable to the entire next-read court family. This is a pre-existing dead-surface
exposure, not a defect in W984lh's repairs — W984lh's courts pin the live path (M1c/
M2/M3/M4c all killed). Disposition for the ledger: either court the procedural fallback
directly (force the reactor to fail) or retire it.

## Mutation Matrix

| # | Subject (lane) | Court | Mutated surface | Mutation | Result | Verdict |
|---|---|---|---|---|---|---|
| M1 | next-read (W984lh) | next_read_test | `lib/xaas/library/ranker.ex` (procedural `curation_score` → `0.0` unconditionally) | zero the procedural curation factor | 14 passed, EXIT=0 | **SURVIVED** — procedural fallback never executes; reactor path masks it entirely |
| M1c | next-read (W984lh) compound leg | next_read_test | `lib/xaas/library/reactors/recommendation_pipeline_reactor.ex` `:extract_curated_ids` | `Enum.map(& &1.book_id)` → `Enum.map(fn _ -> nil end)` (curated-id set nulled in the live path) | 12/14, court RED (`rec_top.factors.curation == 1.0` and weight-override `hd(recs)` pins fail) | **KILLED** (compound) |
| M2 | next-read (W984lh) | next_read_test | `lib/xaas/library/reactors/steps/score_book.ex` `compute_grade_fit/2` | `max(0.0, 1.0 - delta * 0.3)` → `1.0` (grade-fit collapse) | 12/14, court RED (`rec_low.factors.grade_fit <= 0.20` and weight-override pins fail) | **KILLED** |
| M3 | next-read (W984lh) | next_read_test | `score_book.ex` `compute_collab/3` acceptance boost | `min(1.0, base_score + 0.25)` → `base_score` (acceptance boost deleted) | 13/14, court RED (`rec_candidate.factors.collab > rec_other.factors.collab` pin fails) | **KILLED** |
| M4 | next-read (W984lh) | live deepening court | `recommendation_pipeline_reactor.ex` `:rank_candidates` sort | `Enum.sort_by(..., :desc)` → `:asc` | 4 passed | **SURVIVED single vs live court** — `expected_ranking!/2` calls the same `Ranker.rank_recommendations/2`: a shared-oracle tautology, any internal ranker transformation flips both sides identically |
| M4c | next-read (W984lh) compound leg (same mutant, different court) | next_read_test | same sort flip | — | 13/14, RED (weight-override `hd(recs).book.id == book_a.id` pin fails) | **KILLED** (compound across courts) |
| N1 | 204 fix (W984kk) | fabric court W984js | `execution_fabric_controller.ex` `mcp_typed/2` | `:notification -> send_resp(conn, 204, "")` → `:notification -> json(conn, :notification)` (revert to pre-W984kk residue) | 9/10, RED (`assert conn.status == 204` fails — Jason encode of the atom raises, rescue arm answers JSON-RPC -32603 500) | **KILLED** — the court pins the exact `send_resp(conn, 204, "")` shape; reverting W984kk's fix reproduces a spec-violating non-204 |
| N2 | 204 fix (W984kk) compound leg | fabric court W984js | same arm | `send_resp(conn, 204, "")` → `send_resp(conn, 204, "notification")` (non-empty 204 body — probes whether the body pin is load-bearing beyond the status pin) | 9/10, RED (`assert conn.resp_body == ""` fails) | **KILLED** — body-silence pin is independently load-bearing, not masked by the status pin |

## Standing Verdicts

- M1 `ranker.ex` procedural fallback surface: **VACUOUS under all current courts** —
  ~160 lines unobservable (reactor path masks). Flagged above.
- M1c curation factor (live path): **NON-VACUOUS** — the W984lh court genuinely pins
  the curated-id extraction, not just the fixture names.
- M2 grade-fit decay: **NON-VACUOUS** — value pin `<= 0.20` catches total collapse.
- M3 collab acceptance boost: **NON-VACUOUS** — the accepted-log boost test pins the
  +0.25 delta against a real prior accepted RecommendationLog row.
- M4/M4c ranking order: live court alone is a **shared-oracle tautology** (survives any
  internal ranker transform); ordering is pinned only by next_read_test's
  `hd(recs)` identity pin. Flagged for the ledger: the live court pins
  surface-vs-ranker agreement, which is still valuable, but it is not an independent
  correctness oracle for rank order.
- N1 W984kk 204 fix: **NON-VACUOUS** — reverting the fix reproduces a non-204 and the
  court goes RED on the status pin.
- N2 204 body silence: **NON-VACUOUS** — the `resp_body == ""` pin is independently
  load-bearing (W984lc-style compound leg).

Totals: 8 legs — 6 KILLED, 2 single SURVIVED, both survivors killed by compound legs
(M1→M1c, M4→M4c). No unredeemed survivor. Every kill was an exact typed/value assertion
(curation factor pin, grade-fit ceiling, collab delta, `hd(recs)` identity, 204 status,
empty-body silence) — no crash-only kills.

## Tree Cleanliness

Every restore `cmp`-verified byte-identical to the pre-mutation working-tree snapshot.
`git status --porcelain` on all four touched surfaces (ranker.ex, reactor, score_book.ex,
execution_fabric_controller.ex) is EMPTY — clean vs HEAD. The court test files
(`next_read_test.exs`, `next_read_live_deepening_test.exs`, `fabric_court_w984js_test.exs`)
remain `M`/`??` exactly as at lane start (their lanes' uncommitted work, preserved
byte-identically). No commit made.

Final green sweep: next_read 14 passed, fabric court 10 passed, live deepening 4 passed.
Note: one intermediate live-deepening run read 3/4 immediately after the final restore;
an immediate re-run with zero tree changes returned 4/4 — classified as a transient
PubSub/timing flake under concurrent lane load, not mutation residue (tree was
`cmp`-verified clean at that point).

Standing: **ALIVE** — non-vacuity observed on exact subjects (W984lh next-read courts,
W984kk 204-silence fix via W984js court) on branch feat/playwright-surface, this lane.

## Replay

```bash
cd /Users/sac/xaas
export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984me
# baseline: next_read (14), live deepening (4), fabric court W984js (10), all exit 0
# apply one mutation from the matrix, run the paired court, expect RED
# restore from /tmp/w984me/*.orig (cp), cmp-verify byte-identical, court returns green
```

## Cleanup

`rm -rf _build-laneW984me` executed; directory confirmed absent (shutil fallback not
needed). No lane lease remains.
