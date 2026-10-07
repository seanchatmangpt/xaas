# W634 — Art. 14(4)(a) explanation-suppression counterfactual row

Lane: W634 · repo `/Users/sac/xaas` @ `feat/playwright-surface` · build root `_build-laneW634` (partial cold-root, ash_a2a dep compile fails from cold; deletion denied by permission — root remains on disk for the coordinator to remove at integration).

## Task

The dissertation's Art. 14(4)(a) row specifies a halt-gate: suppress the decision when
attributions do not cover the recorded check log. Our honest architecture does NOT halt —
it degrades with a typed signal. Test what is TRUE.

## Landed diff (contract files only)

- `test/eu_ai_act/counterfactual_test.exs` — extended, all pre-existing rows preserved.
  - Row "Art 14(4)(a): degradation-with-signal (not halt) — counterfactual_available false + anatomy retained":
    real refusal via `Xaas.Semantics.Counterfactual.run/2` over the consent/scope check-list,
    then `AutomationBiasCountermeasure.briefing/2` with `attributions = %{}` (do(Explanation ← ∅)).
    Asserts `{:ok, briefing}` (no halt), `counterfactual_available == false`, non-empty
    `refusal_anatomy == [%{name: :consent_ok, refusal: :REFUSED_NO_CONSENT}]`, full
    `per_check_causes` (unattributed entries degrade to shapley 0.0, never missing), determinism ×2,
    no side effect on the record.
  - Positive row "Art 14(4)(a) positive: full attributions yield counterfactual_available true + per-check causes present":
    full attribution map → `counterfactual_available == true`, every check carries
    verdict + Shapley blame, admit anatomy empty by construction, determinism ×2.

## Honest-design note (disclosed divergence from the dissertation)

The dissertation's halt-gate ("no attribution coverage ⇒ suppress the decision") is **not**
our design and was NOT tested as if it were. Our design is **degradation-with-typed-signal**:
the briefing returns `:ok` with `counterfactual_available: false` and the refusal anatomy
retained — the anatomy IS the explanation under explanation-suppression; the counterfactual
replay is an add-on, not a precondition for an explained verdict. The typed signal is the
anatomy, not the counterfactual.

## Verification (real output)

```
PATH=$HOME/.asdf/shims:$PATH mix test test/eu_ai_act/counterfactual_test.exs
# Result: 25 passed   (twice consecutively — determinism/stability ×2)
```

- File is `async: true`; both rows assert byte-identical repeat briefings.
- Notes for integration:
  - Fresh `_build-laneW634` could not compile deps (`ash_a2a` fails from cold in a fresh
    MIX_BUILD_ROOT: `cannot build released AgentCard: :capability_release_closure_missing`;
    plus one SIGTERM mid-compile). Pre-existing cold-root failure, not lane-introduced;
    verification ran against the shared `_build/test` (test-only diff, no lib compile needed).
  - One transient pre-existing flake observed once in row `Art 5(1)(e)` (line 161) mid-run;
    two consecutive full-file runs are 25/25 green. Not in lane scope (row untouched by W634).
  - The test file is currently untracked in the index (`??`) — staging owned by the
    coordinator/another lane; W634 content is on disk and verified.
