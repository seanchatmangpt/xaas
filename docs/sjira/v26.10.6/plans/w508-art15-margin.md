# W508 — Art.15 Robust Margin Gate (Theorem 5.3)

Lane: W508, EU-AI-Act implementation wave, dissertation Ch5 Art.15.
Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, private build root `_build-laneW508`.

## Scope delivered

- `lib/xaas/semantics/robust_margin.ex` — `Xaas.Semantics.RobustMargin`:
  - `estimate_lipschitz/2`: empirical Lipschitz constant = sup of
    `||f(x1)-f(x2)||/||x1-x2||` over the provided pair set (scalar or L2 vector
    norms). Empty pairs → `{:error, :REFUSED_NO_CALIBRATION_DATA}` (fail-closed).
  - `admit/4`: `Margin(x) = h(E(x)) − L_h·L_E·ε ≥ 0` → `:ADMITTED`;
    `< 0` → `{:error, :REFUSED_ROBUST_MARGIN}`. ε is a call argument
    (zero-config). Typed no-calibration refusal propagates fail-closed.
- `test/xaas/semantics/robust_margin_test.exs` — exact-slope recovery,
  admit/refuse, boundary (margin == 0 admits), closure margin, typed
  refusal propagation, end-to-end gate flip by ε.

## Conditional-certificate honesty note (REQUIRED)

`estimate_lipschitz/2` returns the EMPIRICAL Lipschitz constant, a LOWER BOUND
on the true L over the operating region: the sup is taken only over the
provided sample pairs, and a denser sample can only increase it. Therefore the
`:ADMITTED` verdict is a CONDITIONAL certificate: "Margin ≥ 0 given that the
empirical estimate equals the true Lipschitz constant." The dissertation's
Theorem 5.3 holds given a TRUE Lipschitz constant. v2 scope: replace the
empirical estimate with a certified constant via interval arithmetic, upgrading
the conditional certificate to an unconditional one.

## Verification (executed 2026-10-06, MIX_ENV=test, _build-laneW508)

- Strict compile: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW508 mix compile
  --warnings-as-errors` (incremental, robust_margin.ex touched) — zero
  warnings attributable to `robust_margin.ex`. (Whole-app from-scratch strict
  gate is blocked by pre-existing warnings in another lane's untracked
  `lib/xaas/semantics/dataset_admission.ex` — unused `state`, deprecated
  `:rand.uniform_real/1` — not session-introduced, not in lane scope.)
- Test tail (real output):

```
Finished in 0.02 seconds (0.02s async, 0.00s sync)

Result: 10 passed
EXIT=0
```

Note: during the wave, an initially-mid-write sibling lane file
(`counterfactual.ex`, TokenMissingError) transiently blocked app compilation;
it was completed by its owning lane and re-runs passed. Not session damage.

## Receipt fields

- identity: lane W508, xaas @ feat/playwright-surface, files listed above.
- authority: lane contract (3-file write scope, respected).
- consequence: new pure module + tests; no existing surface touched.
- replay: commands above, any checkout at branch head.
- standing: see verdict tail (ALIVE only with real test output appended below).
