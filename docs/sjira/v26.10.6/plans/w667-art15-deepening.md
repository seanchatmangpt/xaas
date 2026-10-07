# W667 — Art. 15 Deepening (accuracy / robustness / cybersecurity)

Lane receipt, xaas v26.10.6, branch `feat/playwright-surface` (canonical checkout, no worktree).

## Before

`test/eu_ai_act/art15_deepening_test.exs` did not exist. Existing coverage:
`test/xaas/semantics/robust_margin_test.exs` (4 + 5 + 1 tests: exact-slope
recovery, single admit/4 verdicts, one end-to-end Theorem 5.3 flip; no property
sweeps, no overflow refusals, no malformed-input coverage, no DatasetAdmission
W1-bound coverage in this file's scope). `DatasetAdmission` had its own suite
elsewhere; this lane deepens the Art. 15 evidenced lines only.

## After

New file `test/eu_ai_act/art15_deepening_test.exs` (18 tests, `@moduletag
:eu_ai_act`, Chicago-style real-module calls, zero mocks):

- **RobustMargin adversarial property sweeps** (seeded via
  `:rand.seed(:exsss, :erlang.phash2(tag))`, deterministic):
  - epsilon monotonicity over 200 draws x 11 radii: once
    `{:error, :REFUSED_ROBUST_MARGIN}`, never re-`ADMITTED` at a larger radius;
  - ADMITTED region downward-closed in the margin (boundary `penalty` admits,
    `0.999*penalty` refuses);
  - empirical-Lipschitz monotonicity in sample count: densification of pair
    sets never lowers the estimate (x^2 scoring, 50 trials; vector linear map,
    coincident-pair invariance).
- **DatasetAdmission W1-slice bound** under seeded perturbation: identical
  populations admit with `w1_proxy == 0.0`; sub-bound seeded perturbations keep
  `w1_proxy <= epsilon_bias` (20 seeds, typed-verdict-tolerant assertion);
  large shift refuses `{:error, {:REFUSED_BIAS_THRESHOLD, ...}}` with bound
  echoed; seed-determinism (same seed -> identical W1, positive finite under a
  different seed); monotone W1 growth in shift magnitude; typed refusals
  (`REFUSED_EMPTY_DATASET`, `{:REFUSED_INCOMPLETE_DATASET, completeness:
  0.75 / threshold: 0.95}`, one-sided-population fail-closed).
- **Typed refusals asserted by exact atom**: `:REFUSED_MALFORMED_MARGIN_INPUT`
  (string margin, nil, list, arity-1 closure, negative l_h/l_e/epsilon),
  `:REFUSED_NO_CALIBRATION_DATA` propagation, `:REFUSED_ARITHMETIC_OVERFLOW`
  (1.0e308 penalty product; 1.0e308-extreme pair in `estimate_lipschitz/2`),
  coincident-pair slope 0.0.

## During-lane events

- **Module fix landed in-tree mid-lane (not by this lane)**: W659e/W676
  identified `RobustMargin.admit/4` CaseClause-crashing on non-numeric margin /
  non-0-arity closure (`lib/xaas/semantics/robust_margin.ex:107`). A repair lane
  added the guard `(is_number(margin) or is_function(margin, 0))` to the
  admit-body clause as an uncommitted working-tree edit. This lane wrote its two
  MALFORMED-margin tests to the typed-refusal contract (`{:error,
  :REFUSED_MALFORMED_MARGIN_INPUT}`, the module's spec atom) and they are green
  against the repaired tree. If that working-tree fix is reverted, those two
  tests fail by design (executable compliance pressure pending W676 merge).
- **This lane's own fix**: initial `rng/1` passed a raw tag tuple to
  `:rand.seed/2` (`FunctionClauseError` in `exsss_seed/1`); fixed to
  `:erlang.phash2(seed_tag)` (test line ~23). Initial `sample/2` fixture
  computed `value * 2.0` which overflowed at 1.0e308 before reaching the module;
  fixed to `value * 1.0`.

## Command + tail

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW667 \
  mix test test/eu_ai_act/art15_deepening_test.exs --include eu_ai_act
```

Green tail:

```
Running ExUnit with seed: 135322, max_cases: 32
Excluding tags: [:stress, :kind, :requires_cnv_deploy, ...]
Including tags: [:eu_ai_act]
..................
Finished in 0.1 seconds (0.1s async, 0.00s sync)
Result: 18 passed
```

(First run without `--include eu_ai_act`: 0 tests, 18 excluded — the suite tag
is excluded by default per `test/test_helper.exs:66-68`; include flag is
mandatory. Pre-run with the tag included before the two fixture/seed fixes:
15/18 passed, 3 failures — 1 own-helper overflow, 2 = the W676 module defect,
both resolved.)

Standing: ALIVE (test file, exact subject `feat/playwright-surface` working
tree, real execution observed 2026-10-07). No commits made; module guard fix
owned by W676. Lane build root `_build-laneW667`: `rm` denied by session
permissions — left on disk for coordinator cleanup (per lane contract).
