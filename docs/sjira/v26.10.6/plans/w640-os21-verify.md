# W640 — OS-21 verification (W630 totality fixes landed)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, build root `_build-laneW640`.
Files touched (within lane contract): this receipt only.

## Flipped-test inventory (test/xaas/semantics/admission_fuzz_test.exs, 432 lines)

Lines 335–431 contain the four W630 FLIP tests, each asserting typed verdicts ×2
deterministic:

- **FLIP-1** (`test "FLIP-1: RobustMargin.admit/4 guard-domain mismatches refuse typed, not raise"`, line 337): 8 malformed quads → `{:error, :REFUSED_MALFORMED_MARGIN_INPUT}` ×2.
- **FLIP-2** (line 355): 3 corpora of non-enumerable `:features` / non-map samples → typed refusal via `assert_match_dataset/3` (incomplete/bias/overflow) ×2.
- **FLIP-3** (line 375): 5 improper-list candidates → 2-tuple verdicts with declared refusal atoms; opaque leaf `%{techniques: [1 | 2]}` → `{:ok, :admitted}` ×2.
- **FLIP-4** (line 406): max-finite penalty product (RobustMargin), list-norm square (estimate_lipschitz), quantile interpolation (DatasetAdmission) → `{:error, :REFUSED_ARITHMETIC_OVERFLOW}` ×2.

Moduledoc (lines 13–38) documents all four escapes as fixed and asserted.

## Verification — real output

### 1. Fuzz suite

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW640 \
  mix test test/xaas/semantics/admission_fuzz_test.exs
→ Result: 9 passed, exit 0
```

### 2. Independent probes (w621 escape recipes, not the flipped tests), ×2 determinism

```
P1 RobustMargin.admit(1.0, -1.0, 1.0, 0.1)
   run1={:error, :REFUSED_MALFORMED_MARGIN_INPUT}
   run2={:error, :REFUSED_MALFORMED_MARGIN_INPUT}   deterministic=true

P2 DatasetAdmission.admit([%{features: 5, label: 0, sensitive: 0}], seed: 1, epsilon_bias: 0.5)
   run1={:error, {:REFUSED_BIAS_THRESHOLD, %{epsilon_bias: 0.5, w1_proxy: :inf}}}
   run2=…same…                                      deterministic=true

P3 EuAiActAdmission.admit(%{techniques: [1 | 2]})
   run1={:ok, :admitted}                            run2 identical, deterministic=true

P4a RobustMargin.admit(1.0, max_finite, max_finite, max_finite)
   run1={:error, :REFUSED_ARITHMETIC_OVERFLOW}      deterministic=true
P4b DatasetAdmission quantile-interpolation overflow corpus (±max_finite)
   run1={:error, :REFUSED_ARITHMETIC_OVERFLOW}      deterministic=true
```

No FunctionClauseError (P1), no Protocol.UndefinedError (P2, P3), no badarith
(P4a, P4b). All verdicts typed and deterministic.

## Verdict

**OS-21 CLOSED** — 4/4 escapes typed-handled (independent probes) and the fuzz
suite asserts the handling (FLIP-1..4 green). Residual: none within OS-21 scope.
