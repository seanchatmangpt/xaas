# W703 — autofde-lab → xaas gap wave

Lane W703, v26.10.6 convergence campaign. Subject: `/Users/sac/xaas` @ `feat/playwright-surface`
(HEAD at lane start: `d1db2b03`), ONE canonical checkout, no worktrees, no commit.
Private build root: `/Users/sac/xaas/_build-laneW703` (lease — coordinator deletes at integration
per the 2026-10-01 cleanup law).

## Audit sources (autofde-lab)

* `/Users/sac/autofde-lab/ontology/airo_risk_description.ttl` — AIRo risk description: risks
  `Risk_SilentUndercount` (env-blocked folded into the denominator) and
  `Risk_MisclassificationDrift` (success flags lying vs grader ground truth: measured 6.7% vs
  claimed 75%), risk sources `Source_EnvironmentBlockedClass` (0-file Helm `chart_path`, 10/25)
  and `Source_GraderClassificationGap`, controls `Control_SregymComparisonEvidence` (raw TSV on
  disk, re-derived in test), `Control_YieldAccounting` (grader-field contract test),
  `Control_PlannerCourts`.
* `/Users/sac/autofde-lab/tests/ontology/test_airo_risk_description.py` — parse + structure +
  every cited `file:` path exists on disk.
* `docs/2026-08-09-representative-sample-batch-results.tsv` — measured-vs-published raw data on
  disk.

## Gap table

| # | autofde-lab pattern | xaas state at lane start | gap? | fill |
|---|---|---|---|---|
| G1 | Grader-classification honesty: success flags verified against outcome state, never trusted (`Source_GraderClassificationGap`) | `Xaas.Sjira.Yield.mine/2` classifies success by documented rule; `yield_test.exs` covers BLOCKED:DISK/PARTIAL_ALIVE/no-result but no court pins the full flag-vs-state contract (missing `completed`, grader-negative verdicts) | YES (partial) | `test/xaas/sjira/yield_grader_honesty_chicago_test.exs` — real `Yield.mine_file!/1` over real OCEL fixtures: missing `completed` → 0 successes; `completed=False` + perfect standing/verdict → 0; `BLOCKED:ENVIRONMENT` → never a silent win; verdict `fail`/`Refused` deny success, `PASS` alone never fabricates it; mined `success_rule` string discloses the failure vocabulary |
| G2 | `Risk_SilentUndercount`: env-blocked counted as model failures | `Xaas.Sjira.Yield` folds `BLOCKED:ENVIRONMENT` into the same denominator as model failures (as non-success, disclosed only via `success_rule`) | YES — RESIDUAL, OPEN (lib change out of lane contract; tests only) | Court pins the *disclosure* control: `success_rule` names BLOCKED, blocked outcome visibly in denominator (n=2). Residual recorded here: a future lane with lib authority should separate `BLOCKED:ENVIRONMENT` into its own class/standing bucket in `Xaas.Sjira.Yield.outcome/2` |
| G3 | Typed environment-blocked detection (0-file chart_path class separated, never silent) | e2e: all 8 `test.skip(` sites carry named reasons; ExUnit: w155 typed-skip convention exists — but NOTHING enforces the convention against regression | YES | `test/xaas/typed_skip_discipline_chicago_test.exs` — disk court over real `e2e/*.spec.cjs` (every `test.skip(` must carry a named reason string; ≥8 sites) + no bare `skip: true` anywhere in `test/**/*.exs` |
| G4 | sregym-comparison measured-vs-claimed evidence discipline (measured vs published, raw data on disk) | PRESENT — verified, no gap. `Xaas.Semantics.DeclaredMetrics` reads every metric from cited receipt files at call time, fail-closed `{:error, :REFUSED_METRICS_SOURCE_MISSING}`; w536's `declared_metrics_test.exs` re-derives accuracy from the w316 receipt, robustness from the refusal ledger, and proves fail-closed on a missing source | NO | Verified only; receipt row here |
| G5 | Yield accounting (grader-field contract test) | PRESENT — `yield_test.exs` pins exact n/successes/yield against the real v26.9.22 OCEL subset fixture, re-read through `mine_file!/2` with sha256 source stamping | NO | Verified only |

## Diffs (all new files; no lib changes in this lane)

* `test/xaas/sjira/yield_grader_honesty_chicago_test.exs` (new, 6 courts)
* `test/xaas/typed_skip_discipline_chicago_test.exs` (new, 2 courts)
* `docs/sjira/v26.10.6/plans/w703-autofde-gaps.md` (this receipt)

## Verification (real run, 2026-10-07, fresh `_build-laneW703` under pinned asdf toolchain)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW703 \
  mix test test/xaas/sjira/yield_grader_honesty_chicago_test.exs \
           test/xaas/typed_skip_discipline_chicago_test.exs
Result: 7 passed

$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW703 \
  mix test test/xaas/sjira/yield_test.exs test/xaas/semantics/declared_metrics_test.exs
Result: 13 passed
```

Transport notes: fresh-root `mix deps.compile ash_a2a` failed once with
`cannot build released AgentCard: :capability_release_closure_missing` (parallel-compile race in
`AshA2A.Chicago.Bench.B11Wire` card expansion); a direct `mix deps.compile ash_a2a` retry
compiled clean (`Generated ash_a2a app`, exit 0) and everything downstream was green — no
config change made, pre-existing flake, not session-introduced.

## Falsifiers

* G1: a `completed`-missing or grader-negative-verdict event counted as a success → court fails.
* G3: any future reason-less `test.skip(` or bare `skip: true` → court fails.
* G2 residual: mined output gains a BLOCKED-separated bucket ⇒ residual closed; until then the
  court asserts only the disclosure control, never the fold itself.
