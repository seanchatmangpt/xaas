# W621 — Admission-Gate Totality Fuzz (EU-AI-Act wave)

Lane W621 · Repo `/Users/sac/xaas` @ `feat/playwright-surface` (canonical checkout, build root `_build-laneW621`, `MIX_ENV=test`).

## Scope

Seeded deterministic property fuzz — 500 adversarial cases per gate, `:rand.seed(:exsss, {1760, 421337, 991511})` — over three admission surfaces, asserting (P1) totality (no raise; verdict is `{:ok, _}` / `{:error, atom-in-declared-set}`) and (P2) determinism (same input twice → identical verdict):

| gate | surface | corpus |
|---|---|---|
| Art. 5(1) intent admission | `Xaas.Semantics.EuAiActAdmission.admit/1` | 500 arbitrary adversarial maps (schema + junk keys incl. unicode/empty/integer keys; values: atoms, binaries, 1 MB payload, 250-deep nesting, ±max-finite 1.7976931348623157e308, negative ints/floats, empty maps/lists) + 7 non-map inputs |
| Art. 10 dataset admission | `Xaas.Semantics.DatasetAdmission.admit/2` | 500 shape-valid corpora (≤6 samples, map samples only) with adversarial numeric feature values bounded to 1e150 (see CRITICAL-4) |
| Art. 15 robustness gate | `Xaas.Semantics.RobustMargin.estimate_lipschitz/2` + `admit/4` | 500 adversarial calibration pair-sets (numerics ≤1e150, coincident inputs); 500 guard-domain numeric quads (constants ≤1e100, margins ≤1e150, margin as number and as zero-arity closure) |

## Environment boundary (recorded, not a gate defect)

Exact ±inf/NaN are UNCONSTRUCTIBLE on this BEAM (OTP 28 / stdlib 7.3): float arithmetic
overflow raises `badarith`/`ArithmeticError`; `:erlang.binary_to_term/1` rejects a
non-finite `NEW_FLOAT_EXT`; bit-syntax `<<v::float>>` refuses infinite bits;
`math:inf/0`/`math:nan/0` are not exported. The "NaN-adjacent float" fuzz class is
therefore proxied by ±max-finite (1.7976931348623157e308) and bounds are chosen so
the fuzz itself stays inside the representable range (numerics ≤1e150 in arithmetic
positions, penalty constants ≤1e100 since the penalty is a triple product).

## Findings — all probe-verified by execution (mix run, lane build root, MIX_ENV=test)

### CRITICAL-1: `RobustMargin.admit/4` is not total — guard mismatch raises

`robust_margin.ex:88-90`: `admit/4` has two clauses — the
`{:error, :REFUSED_NO gain...}` ... (see probe output) — no catch-all. Executed probe:

```
P1 RobustMargin.admit(1.0, -1.0, 1.0, 0.1)
=> RAISE ** (FunctionClauseError) no function clause matching in Xaas.Semantics.RobustMargin.admit/4
```

### CRITICAL-2: `DatasetAdmission.admit/2` escapes on non-enumerable `:features`

`dataset_admission.ex:138` — `vector/1` calls `Enum.sort_by(features, ...)`
unguarded. Executed probe:

```
P5 DatasetAdmission.admit([%{features: 5, label: :x, sensitive: 0}], seed: 1)
=> RAISE ** (Protocol.UndefinedError) protocol Enumerable not implemented for Integer
```

Note (typed, not a raise): non-map samples do NOT escape — a non-map element is
silently filtered by `for(s = %{} <- samples)`; probe P4
`DatasetAdmission.admit([5], seed: 1)` returned
`{:error, {:REFUSED_BIAS_THRESHOLD, %{w1_proxy: :inf, epsilon_bias: 0.1}}}` — typed
fail-closed, though `:inf` is a non-number in the "measured quantity" field (documented
proxy behavior per the module doc).

### CRITICAL-3: improper lists escape `EuAiActAdmission.admit/1`

`List.wrap/1` is identity on lists, so an improper list reaches `Enum.any?/2` unguarded. Executed probe:

```
P6 EuAiActAdmission.admit(%{techniques: [1 | 2]})
=> RAISE ** (FunctionClauseError) no function clause matching in Enum.predicate_list/3
```

### CRITICAL-4: float overflow raises `ArithmeticError` in every arithmetic position

The BEAM raises `ArithmeticError` whenever a float op produces ±inf — even between two
finite operands (verified: `-1.7976931348623157e308 - 1.0e300` → `ArithmeticError`;
`1.0e300 * 1.0e100` → `ArithmeticError`). Overflow-capable sites in all three gates:

- `robust_margin.ex:97` — `l_h * l_e * epsilon` (triple product; observed in-fuzz:
  `9.999999999999999e299 * 1.0e100` → ArithmeticError)
- `robust_margin.ex:99` — `margin_value - penalty`
- `robust_margin.ex:108-115` — `sub/2`/`norm/1` under `estimate_lipschitz/2`:

```
P3 estimate_lipschitz(fn x->x*2.0 end, [{1.7976931348623157e308, -1.7976931348623157e308}])
=> RAISE ** (ArithmeticError) bad argument in arithmetic expression
```

- `dataset_admission.ex:210-213` — quantile interpolation `a + (b - a) * frac`.

Arithmetic-position fuzz numerics are therefore bounded to ≤1e150 (constants ≤1e100);
the escapes are real totality violations inside the gates' otherwise-admitted domain.

## Verdicts

| gate | totality | determinism |
|---|---|---|
| `EuAiActAdmission.admit 500 maps + 7 non-maps` | HELD on standard-term corpus (CRITICAL-3 outside corpus) | HELD |
| `DatasetAdmission.admit/2` (map samples, numerics ≤1e150) | HELD on included corpus (CRITICAL-2/4 outside corpus) | HELD |
| `RobustMargin.estimate_lipschitz/2` (numerics ≤1e150) | HELD on included corpus (CRITICAL-4 outside corpus) | HELD |
| `RobustMargin.admit/4` (guard domain, constants ≤1e100) | HELD on included corpus (CRITICAL-1/4 outside corpus) | HELD |

## Receipt

- Case count: 500 × 3 gates (1500 fuzz cases; 1507 total admit invocations incl. non-map inputs and empty-corpus test), each evaluated twice for determinism.
- Falsifier actually run: `PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW621 MIX_ENV=test mix test test/xaas/semantics/admission_fuzz_test.exs` → **5 passed, 0 failed**.
- Environment: elixir 1.20.2-otp-28 / erlang 28.5 (asdf pinned toolchain), lane build root `_build-laneW621`.
- Repair posture: totality NOT universal — CRITICAL-1..4 filed verbatim, unrepaired per lane contract ("file verbatim, do not fix").
- Repair owner: the owning gate lane (W500/W502/W508) for each CRITICAL above.