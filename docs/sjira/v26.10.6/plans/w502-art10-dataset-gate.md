# W502 — Art. 10 Dataset Admission Gate (Theorem 3.2)

Lane: W502 · Wave: EU-AI-Act implementation · Repo: `/Users/sac/xaas` @ `feat/playwright-surface`

## Contract files

- `lib/xaas/semantics/dataset_admission.ex` — `Xaas.Semantics.DatasetAdmission.admit/2`
- `test/xaas/semantics/dataset_admission_test.exs`
- this receipt

## Design

`admit/2` over empirical samples (`%{features: map, label, sensitive: 0|1}`):

1. `[]` → `{:error, :REFUSED_EMPTY_DATASET}`
2. completeness (share of non-nil `:required_fields`, field-level) `< 1 - η`
   → `{:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness, threshold}}}`
3. empirical W1 proxy `> ε_bias`
   → `{:error, {:REFUSED_BIAS_THRESHOLD, %{w1_proxy, epsilon_bias}}}`
4. else `{:ok, :ADMITTED, %{w1_proxy, completeness, projections}}`

ε, η, seed, projection count, and required fields are all call arguments —
zero-config safety path (no application-env).

## Honest limitation (documented in @moduledoc)

Exact empirical Wasserstein-1 is O(N³ log N) (network simplex / Sinkhorn) —
v2. This lane implements **sliced Wasserstein-1** (Bonneel et al.): k seeded
pseudo-random unit directions, exact 1-D W1 per direction via sorted-quantile
L1 (linear interpolation, handles unequal group sizes), averaged. It is a
documented **upper-bound proxy**, polynomial time; typed gate semantics are
identical to the exact path. Fail-closed: if either sensitive population is
empty, W1 is returned as `:inf`, forcing `REFUSED_BIAS_THRESHOLD`.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW502 \
  mix test test/xaas/semantics/dataset_admission_test.exs
```

Test coverage: balanced → ADMITTED; skewed sensitive-conditioning →
REFUSED_BIAS_THRESHOLD; missing required fields → REFUSED_INCOMPLETE_DATASET;
seeded determinism (identical verdict+measurement, twice); empty dataset →
typed REFUSED_EMPTY_DATASET; one-sided sensitive population → fail-closed bias
refusal.

## Receipt

- generated vs handwritten: handwritten (irreducible residue; no generator profile for this surface)
- verdict: **ALIVE (lane-scoped)**

### Test tail (real output, 2026-10-06)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW502 \
    mix test test/xaas/semantics/dataset_admission_test.exs
Running ExUnit with seed: 593721, max_cases: 32
Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api,
  :external, :external_llm, :subprocess, :property, :castle_kernel, :eu_ai_act]
......
Finished in 0.03 seconds (0.03s async, 0.00s sync)
Result: 6 passed, 0 failures
```

Verdict counts: 6/6 passed. `mix compile` in the lane build root reached the
app target with no diagnostics attributable to lane files. (Two transient
compile failures during the run were sibling-lane mid-write churn on
`lib/xaas/actuation/quiescent_stop.ex` and `lib/xaas/semantics/counterfactual.ex`
— files outside this lane's contract; both compiled clean on retry.)

Honest limitation: sliced W1 is a seeded upper-bound proxy of exact empirical
W1 (network simplex deferred to v2); gate semantics (typed ADMITTED/refusals,
call-argument thresholds) are identical between proxy and v2.
