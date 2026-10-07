# W676 — Margin/Dataset Hardening (typed refusals on malformed margin + extreme-float dataset features)

- **Lane**: W676, xaas v26.10.6 campaign
- **Subject**: branch `feat/playwright-surface` @ a0723bf6 (canonical checkout /Users/sac/xaas), no commit
- **Sources**: W659e reproduced run (`docs/sjira/v26.10.6/plans/w659e-euaia-run.md`)

## Before (reproduced)

- `RobustMargin.admit("ten", 1.0, 1.0, 1.0)` → `CaseClauseError` (inner
  `case margin` in the numeric clause had no catch-all; the outer catch-all
  clause was unreachable because all numeric guards passed).
- `RobustMargin.admit(fn x -> x end, 1.0, 1.0, 1.0)` → `CaseClauseError` (same path).
- `DatasetAdmission.admit/2` with a `1.0e308` feature **does return the typed
  `{:error, :REFUSED_ARITHMETIC_OVERFLOW}`** via the existing W630 rescue arm —
  verified live. The W659e-observed ArithmeticError at art15_deepening_test.exs
  lines 172/262 originates in the *test helper* (`y: value * 2.0` overflows at
  1e308 during sample construction), i.e. a W667-owned file defect, not a lib
  gate defect. No lib change needed or made to `dataset_admission.ex`; the
  regression test pins the typed refusal contract and documents the boundary.

## Diff (μ)

- `lib/xaas/semantics/robust_margin.ex` — added
  `(is_number(margin) or is_function(margin, 0)) and` to the guard of the
  numeric `admit/4` clause. Non-numeric / non-0-arity margins now fall through
  to the existing W630 catch-all → `{:error, :REFUSED_MALFORMED_MARGIN_INPUT}`.
  Refusal atom set unchanged (closed; reuses existing atom). Doc/spec unchanged
  in spirit (spec already listed the refusal). Handwritten, 1 guard, 1 file.
- `test/xaas/semantics/robust_margin_test.exs` — 2 regression tests (real
  calls, exact-atom asserts, mutation rationale comments).
- `test/xaas/semantics/dataset_admission_test.exs` — 1 regression test
  (extreme-float feature → exact `{:error, :REFUSED_ARITHMETIC_OVERFLOW}`,
  helper avoids test-side overflow).
- Untouched (W667-owned): `test/eu_ai_act/art15_deepening_test.exs`.

## Verification (real output)

```
mix test test/xaas/semantics/robust_margin_test.exs \
  test/xaas/semantics/dataset_admission_test.exs \
  test/eu_ai_act/art15_deepening_test.exs --include eu_ai_act
# MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW676, pinned asdf toolchain
Running ExUnit with seed: 932108, max_cases: 32
Finished in 0.08 seconds
Result: 37 passed
```

## Mutation checks (defect reintroduced → tests fail)

1. robust_margin guard: removing `(is_number(margin) or is_function(margin, 0)) and`
   → `Result: 10/12 passed`, **2 × `** (CaseClauseError)`** (both W676 tests
   fail). Restored, re-ran green.
2. dataset_admission rescue arm → `raise ArithmeticError, message: "mutated"`
   → `Result: 6/7 passed`, `** (ArithmeticError) mutated` (W676 overflow test
   fails). Restored, re-ran green.

## Coordination (W667 contract)

`{:error, :REFUSED_MALFORMED_MARGIN_INPUT}` and
`{:error, :REFUSED_ARITHMETIC_OVERFLOW}` are exactly the atoms asserted in
W667's `test/eu_ai_act/art15_deepening_test.exs` (lines 122-139, 264-266);
final run includes that file green (its 18 tests pass with `--include eu_ai_act`).

## Standing

- Lane files: ALIVE (typed refusals witnessed on the exact subject by real
  calls + mutation-killed regression tests, 37/37 green final run).
- Open (outside lane): the art15 helper's own `value * 2.0` overflow at
  sample-construction time is a W667-file fix (helper-side); the lib gate
  already refuses typed for extreme features.
- No commit made (per lane contract). `_build-laneW676` deleted.
