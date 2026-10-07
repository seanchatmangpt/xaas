# W630 — OS-21: admission-gate totality fix (4 w621 escapes)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, build root `_build-laneW630`.
Files touched (all within lane contract; no other files modified):

- `lib/xaas/semantics/robust_margin.ex`
- `lib/xaas/semantics/dataset_admission.ex`
- `lib/xaas/semantics/eu_ai_act_admission.ex`
- `test/xaas/semantics/admission_fuzz_test.exs`

## Per-escape fix summary

1. **RobustMargin.admit/4 guard-domain mismatch (FunctionClauseError).**
   Catch-all clause added after the guard clause:
   `def admit(_m, _lh, _le, _eps), do: {:error, :REFUSED_MALFORMED_MARGIN_INPUT}`.
   Non-numeric or negative `l_h`/`l_e`/`epsilon` now refuse typed.
   The typed-refusal passthrough clause was generalized to
   `admit(_m, {:error, refusal}, _le, _eps) when is_atom(refusal)` so
   `estimate_lipschitz` typed refusals propagate.

2. **DatasetAdmission non-enumerable `:features` / non-map samples.**
   New `feature_map/1` + `enumerable_features/1` helpers: non-map samples and
   non-enumerable `:features` are treated as missing/empty, so the sample flows
   to the existing typed incomplete (`REFUSED_INCOMPLETE_DATASET`) or bias
   (`REFUSED_BIAS_THRESHOLD`) refusal — never `Map.get`/`Enum.sort_by` raises.
   `vector/1` routes through `feature_map/1`.

3. **EuAiActAdmission improper-list values (Protocol.UndefinedError).**
   `List.wrap/1` replaced with `wrap_field/1`: proper lists pass through; anything
   else (improper lists, binaries, scalars) is wrapped as an opaque singleton leaf
   (`[value]`). `proper_list?/1` = `is_list(:lists.reverse(list))` under
   `rescue [ArgumentError, FunctionClauseError] -> false`. Structural checks run,
   typed atoms return. `%{techniques: [1 | 2]}` → `{:ok, :admitted}` (the opaque
   leaf matches no prohibited class).

4. **Float overflow (badarith).** `try/rescue ArithmeticError` at each gate
   boundary — `RobustMargin.admit/4` (penalty product / margin subtraction),
   `RobustMargin.estimate_lipschitz/2` (sub/norm), `DatasetAdmission.admit/2`
   (quantile interpolation / W1 aggregation) — each returns
   `{:error, :REFUSED_ARITHMETIC_OVERFLOW}`. Rescued at the boundary, not scattered.

## Flip table (w621 escape → W630 assertion)

| # | w621 escape (raised) | W630 flip test | typed verdict now asserted |
|---|---|---|---|
| 1 | `RobustMargin.admit(1.0, -1.0, 1.0, 1.0)` et al. — FunctionClauseError | FLIP-1 (8 malformed quads, x2 deterministic) | `{:error, :REFUSED_MALFORMED_MARGIN_INPUT}` |
| 2 | `DatasetAdmission.admit([%{features: 42, ...}], ...)` — Protocol.UndefinedError | FLIP-2 (3 corpora: non-enumerable features, non-map samples) | typed incomplete/bias refusal via `assert_match_dataset/3` |
| 3 | `EuAiActAdmission.admit(%{techniques: [1 \| 2]})` — Protocol.UndefinedError | FLIP-3 (5 improper-list candidates + opaque-leaf admit case) | `{:ok, :admitted}` for the opaque leaf; declared refusal atoms for join candidates |
| 4 | max-finite float arithmetic — ArithmeticError (all 3 gates) | FLIP-4 (penalty product, list-norm square, quantile interpolation; x2) | `{:error, :REFUSED_ARITHMETIC_OVERFLOW}` |

## Verification (real output)

- `MIX_BUILD_ROOT=_build-laneW630 MIX_ENV=test mix compile --warnings-as-errors` → **exit 0**
  (only remaining log warning is the pre-existing `ash_affidavit` `@envelope_domain_tag`
  warning in a dep app, untouched by this lane).
- `mix test admission_fuzz_test.exs robust_margin_test.exs dataset_admission_test.exs
  eu_ai_act_admission_test.exs` → **Result: 49 passed** (final run, after all fixes).

## Standing

Totality now genuinely HOLDS: every formerly-raising adversarial class returns a typed,
deterministic verdict; the fuzz suite asserts the handling instead of documenting escapes.
ALIVE on the exact subject above.
