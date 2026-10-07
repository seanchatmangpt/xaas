# W692 — Pearl Counterfactual Calculus Deepening (receipt)

- **Lane**: W692, xaas v26.10.6, canonical checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface`, HEAD `a0723bf6`. Not committed (per lane order).
- **Backlog**: deepen the Pearl counterfactual calculus surface
  (Art 14(4) / dissertation ch. 9).
- **Subject**: new file `test/eu_ai_act/counterfactual_deepening_test.exs` (only file
  written besides this receipt). No lib code touched; no mocks; Chicago-style real
  modules, exact values/atoms.

## What landed

`Xaas.EuAiAct.CounterfactualDeepeningTest` (12 tests, `@moduletag :eu_ai_act`):

- **(a) Pearl three-step** on a multi-candidate refusal (real 3-check deterministic
  pipeline; one `verdict/2` causal model feeding both W506 `:ok | {:refused, r}` and
  W505 `:pass | {:refuse, r}` adapters):
  - Abduction: recorded per-check log is the recovered U (exact ordered log asserted).
  - Action: do-intervention `x'` (fix `bias_risk` only) — refusal survives but its
    REASON migrates (`REFUSED_BIAS_THRESHOLD` → `REFUSED_ROBUST_MARGIN`), so
    `changed? == true` with the exact cause-migration explanation string asserted.
  - Prediction: exact outcome, Theorem 7.1 (0/1, no distribution); flipping all
    failing checks flips to `:admitted` with the exact multi-check-flip explanation;
    unfaithful record → `{:error, {:record_outcome_mismatch, {:expected, {true, nil},
    :got, {:refused, :REFUSED_BIAS_THRESHOLD}}}}`.
  - Seeded x3 determinism: three full three-step runs, identical factual U across
    seeds and identical predictions for identical `x'`.
- **(b) Shapley properties** on real `AdmissionAttribution`:
  - Efficiency: Σφ = v(N) − v(∅) = −1.0 exactly (within 1e-9) on the refusal;
    each refusing check −0.5, passing check `=== 0.0`; full admit → all φ 0.0.
  - Symmetry: reversed and rotated candidate lists give identical φ-by-name maps;
    twin refusing candidates get equal φ (−0.5), dummy gets 0.0.
  - Dummy candidate: never-refusing check φ `=== 0.0` under any coalition structure;
    refusing gate alone carries −1.0.
  - Typed refusal: 21-check lattice → `{:error, :COALITION_LIMIT}`.
- **(c) Composed chain**: `Counterfactual.evaluate/3` → `AdmissionAttribution.shapley/2`
  → `AutomationBiasCountermeasure.briefing/2` consumes both — exact briefing:
  `verdict :refuse`, `counterfactual_available true`, interpretability string,
  per-check Shapley values (−0.5/−0.5/0.0), refusal anatomy (bias, margin),
  byte-identical on re-run; full-admit briefing (empty anatomy, zero φ);
  partial attribution map → `counterfactual_available == false` with missing
  candidate defaulted to `shapley: 0.0` (typed field, not silent true).

## Verification (real command + tail)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW692 \
  mix test test/eu_ai_act/counterfactual_deepening_test.exs --include eu_ai_act
............
Finished in 0.1 seconds (0.1s async, 0.00s sync)
Result: 12 passed
```

One iteration failure was repaired (first run 11/12): `changed?` asserted `false` for
the cause-migration case; the module's semantics are that differing refusal reasons
are differing outcomes (`changed? == true`) — test corrected to the module's lawful
behavior, lib untouched.

## Standing

- **ALIVE** for the lane subject: real execution observed on the exact file at HEAD
  `a0723bf6` (uncommitted working tree + receipt). 12/12 passed, `--include eu_ai_act`.
- Compile stderr: one benign pattern-match-on-float warning (matching `0.0` literal)
  at the twin-symmetry assertion — cosmetic, tests pass.
- Pre-existing environment noise (not session-introduced): PromEx/Grafana nxdomain
  warnings on test boot.
- **Lease**: `MIX_BUILD_ROOT=_build-laneW692` deletion was DENIED by the permission
  system in this lane session. Left for the coordinator per the fanout cleanup law
  (437 MB, `/Users/sac/xaas/_build-laneW692`).
- Not committed; coordinator owns the integration commit.
