# W865 — W650c OPEN_GAP-3 fix (DatasetAdmission helper-side overflow)

- **Lane**: W865, xaas v26.10.6 campaign
- **Subject**: branch `feat/playwright-surface` @ a0723bf6 (canonical checkout /Users/sac/xaas), no commit
- **Sources**: W859 typed-gap register row (w859-typed-gap-register.md:58, surface `test/eu_ai_act/art15_deepening_test.exs:172,262`); W676 receipt ("open (outside lane): helper-side W667-file fix")

## Before (reproduced on the exact subject)

The register row names the art15 test helper, but that file is W667-owned and
outside this lane's write set. The DatasetAdmission helper-side site inside
the lane write set is the public helper `sliced_w1/3`: it sits outside
`admit/2`'s W630 gate-boundary rescue, so a direct call raises a raw
ArithmeticError on extreme features:

```
DatasetAdmission.sliced_w1([%{features: %{x: 1.0e308, ...}, sensitive: 0},
                            %{features: %{x: -1.0e308, ...}, sensitive: 1}], 667, 8)
# => raises ArithmeticError (quantile `a + (b - a) * frac`; 1e308 - (-1e308) overflows)
# observed: {:raised, ArithmeticError}  (mix run repro, pinned toolchain)
```

## Diff (μ, handwritten, 2 files)

- `lib/xaas/semantics/dataset_admission.ex`:
  - `sliced_w1/3` body wrapped in the house rescue pattern
    (`ArithmeticError -> {:error, :REFUSED_ARITHMETIC_OVERFLOW}`), same closed
    atom as W630/W676; @spec widened to `float() | :inf |
    {:error, :REFUSED_ARITHMETIC_OVERFLOW}`; @doc updated.
  - `admit/2` now pattern-matches the helper result and passes the typed
    refusal through verbatim instead of term-comparing a tuple against
    `epsilon` (which would have forced a bogus REFUSED_BIAS_THRESHOLD with a
    tuple w1_proxy).
- `test/xaas/semantics/dataset_admission_test.exs`: 2 regression tests —
  direct helper call → exact typed atom; normal inputs unaffected (direct
  sliced_w1 == 0.0 on identical populations, gate still ADMITTED on balanced
  data).

## Verification (real output, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW865, pinned asdf toolchain)

```
mix test test/xaas/semantics/dataset_admission_test.exs \
  test/eu_ai_act/art15_deepening_test.exs --include eu_ai_act   # run 1
# Result: 27 passed
# run 2: Result: 27 passed
```

## Mutation checks

1. sliced_w1/3 rescue arm → `raise ArithmeticError, message: "mutated"`:
   `** (ArithmeticError) mutated`, `Result: 8/9 passed` (the W865 direct-helper
   test fails; admit-level W676 test still passes because admit's own rescue
   arm still shields it — confirming the new test kills exactly the helper
   mutation). Restored, re-ran: `Result: 9 passed`.

## Standing

- Lane files: ALIVE (typed refusal witnessed on the exact subject by a real
  direct helper call + mutation-killed regression test, 27/27 green ×2).
- W650c OPEN_GAP-3: REPAIRED at the DatasetAdmission helper boundary. The
  art15 sample-construction helper itself (`value * 2.0` at
  art15_deepening_test.exs:172,262) remains W667-owned, outside this lane's
  write set — with this fix the lib helper no longer raises, but the test
  helper's own overflow at sample construction is untouched.
- No commit made (per lane contract). `_build-laneW865` deleted.
