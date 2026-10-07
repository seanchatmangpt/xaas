# W659e — eu_ai_act suite receipt @ post-W631/W637b/W652 tree

- Subject: /Users/sac/xaas @ `feat/playwright-surface` (canonical checkout, lane build root `_build-laneW659e`)
- Date: 2026-10-07
- Command:
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW659e mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/`
- Tail: `Result: 1145/1153 passed` / `Failed: 8 tests` (reproduced identically across 3 runs; build-warm run finishes in ~58s)
- Verdict: **NOT GREEN** — 8 failures, all confined to the W667/W540 deepening additions; **zero failures in the pre-existing W651/W622 baseline corpus**.

## Failures (all 8, classified)

### A. test-harness bug — `rng/1` helper (4 failures)
`test/eu_ai_act/art15_deepening_test.exs:23` — `:rand.seed(:exsss, {:w667, tag})` passes a
non-seed tuple (`{:w667, :eps_monotone}` etc.); `:rand.exsss_seed/1` FunctionClauseError.
Affects the three "adversarial property sweeps" tests and the DatasetAdmission perturbation test.
Fix locus: the test helper, not product — seed must be a proper term (e.g. `:rand.seed_s(:exsss, :erlang.phash2(tag))`-derived or `:rand.seed_s(:exsss, {1,2,tag-hash})`).

### B. product gap — `Xaas.Semantics.RobustMargin.admit/4` typed-refusal guards (2 failures)
`lib/xaas/semantics/robust_margin.ex:107` — CaseClauseError on:
- non-numeric margin constant (`"ten"`) — expected `{:error, :MALFORMED_MARGIN_INPUT}`
- non-1-arity closure — expected `{:error, :MALFORMED_MARGIN_INPUT}`
The deepening tests demand typed refusals; the implementation's case lacks those clauses/guards.

### C. boundary bug — DatasetAdmission W1 overflow (1 failure)
`test/eu_ai_act/art15_deepening_test.exs:172,262` — `sample/2` with `huge` float → ArithmeticError
in the W1-slice computation on extreme population. Expected typed refusal; got an untyped crash.

### D. product seam gap — `VulnerabilityLifecycle.respond/2` after refused skip (1 failure)
`test/eu_ai_act/title_iii_test.exs:766` (deepen_kind at :1032) — Art 15.5.s3 (W540) scenario:
after a lifecycle skip is refused, the subsequent legitimate `respond` returns
`{:error, :REFUSED_LIFECYCLE_SKIP}` instead of `{:ok, %{state: :RESPONDED}}`.
Refusal does not recover for the valid transition.

## Isolation note
Isolated once per contract: ran the full corpus (8 failures), isolated
`art15_deepening_test.exs` and `title_iii_test.exs` with `--trace` for exact stacktraces,
then confirmed the full run reproduces the same 8. One isolation pass, no repair attempted
(contract forbids writes outside the receipt file).

## Classification vs baselines
- W651/W622 baseline corpus (all pre-deepening tests): **GREEN**, 1145 passing.
- All 8 failures are session-wave additions (W667 Art 15 deepening + W540 Title III deepen kind),
  i.e. new deepening tests at `test/eu_ai_act/art15_deepening_test_test.exs` and
  `test/eu_ai_act/title_iii_test.exs` — not regressions against the W651/W622 baselines.
