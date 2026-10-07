# W505 — Art.13 Exact Shapley Attribution Over the Discrete Admission Lattice

Lane: W505, EU-AI-Act wave, repo /Users/sac/xaas @ feat/playwright-surface.
Build root: `_build-laneW505` (lease; coordinator deletes at integration).

## Definition 5.2 mapping

- Discrete lattice = the real ordered admission check list
  `[{name, fun(intent) -> :pass | {:refuse, atom}}]` — not a continuous
  black-box score, so exact enumeration is computable and no sampling
  (Monte Carlo Shapley) is used or needed.
- `v(S) = 1` iff the intent passes every check in S; `v(∅) = 1` vacuously.
- `φ_i = Σ_{S ⊆ N\{i}} [|S|!(n-1-|S|)!/n!] · (v(S∪{i}) − v(S))`, computed by
  enumerating all 2^n coalitions — deterministic, exact.
- Bound documented: O(2^n·n); `n ≤ 20` guard, larger gets
  `{:error, :COALITION_LIMIT}`.
- Efficiency axiom asserted in code: `Σφ_i = v(N) − v(∅)` within 1e-9;
  violation raises `ArgumentError`.
- Analytic cross-checks asserted by tests: single refuser absorbs all blame
  (φ = −1, others 0 — exact since v depends only on S ∩ R); two of four
  refusers split −0.5 each; all-pass gives uniform 0 attribution.

## Files (lane contract)

- `lib/xaas/semantics/admission_attribution.ex` — `Xaas.Semantics.AdmissionAttribution.shapley/2`
- `test/xaas/semantics/admission_attribution_test.exs` — 8 tests
- this receipt

Handwritten: 100% (no generator profile exists for this surface;
UNSUPPORTED(generator-capability) would apply, none was invoked — pure stdlib
module with no app deps).

## Verification (real commands, pinned toolchain elixir 1.20.2-otp-28)

Whole-app `mix compile` in `_build-laneW505` is BLOCKED by two untracked
in-flight files from concurrent lanes (not mine, contract forbids touching):

- `lib/xaas/actuation/quiescent_stop.ex` — missing `require Ash.Query`
  before `Ash.Query.filter/2` (pin operator), compile error at line 91
- `lib/xaas/semantics/counterfactual.ex` — missing closing delimiter at
  line 217

Both `git status` = `??` (untracked). Pre-existing to this lane's session;
not introduced by W505.

Because the module is dependency-free, lane verification ran standalone:

```
$ elixirc --warnings-as-errors -o /tmp/w505a/app \
    lib/xaas/semantics/admission_attribution.ex
MODULE_COMPILE_STRICT_OK

$ elixir -pa /tmp/w505a/app -e 'ExUnit.start(autorun: false);
    Code.require_file("test/xaas/semantics/admission_attribution_test.exs");
    results = ExUnit.run(); ...'
Running ExUnit with seed: 216549, max_cases: 32

........
Finished in 0.3 seconds (0.3s async, 0.00s sync)

Result: 8 passed
results=%{total: 8, failures: 0, excluded: 0, skipped: 0}
W505 ALL TESTS PASSED
RUNNER_EXIT=0
```

Strict compile of the lane module: green (warnings-as-errors). Lane tests:
8/8 green, exit 0, including the 2^20-boundary run (n=20 admitted,
n=21 → `{:error, :COALITION_LIMIT}`) — total 0.3s.

## Standing

- Lane surface (module + tests): ALIVE — exact enumeration witnessed,
  efficiency axiom asserted, determinism exact-equality across 6 runs.
- Whole-app `mix compile` / `mix test`: BLOCKED
  (BLOCKED(CONCURRENT_LANE_COMPILE) — untracked `quiescent_stop.ex`,
  `counterfactual.ex`; resolves when owning lanes land their files).
- No commits made (coordinator owns lane transitions per
  same-checkout-fanout).
