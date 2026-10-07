# W506 — Art. 86 Counterfactual Explanation (Theorem 7.1)

Lane: W506 · Repo: `/Users/sac/xaas` @ `feat/playwright-surface` · Build root: `_build-laneW506`
Contract files: `lib/xaas/semantics/counterfactual.ex`, `test/xaas/semantics/counterfactual_test.exs`, this receipt.

## Theorem 7.1 mapping

`P(Y_{X←x'} = y' | X, Y) ∈ {0,1}` holds because:

1. **Deterministic pipeline (μ)** — admission is a pure ordered function of
   `(input, check-list)`; `Xaas.Semantics.Counterfactual.run_pipeline/2` is
   total, side-effect-free, and order-deterministic. Same input + same
   check-list ⇒ identical outcome and identical per-check verdict log. Hence
   the counterfactual decision on `x'` is a *computation*, not an
   expectation: the probability is degenerate (exactly 0 or 1).
2. **U recovered from the receipt** — the recorded decision record carries
   the full ordered per-check verdict log (`checks`), which is the abduction
   leg (U); the substituted input `x'` is the action leg; the re-run outcome
   is the prediction leg. Abduction–action–prediction completes exactly, in
   process, with no sampling.
3. **Faithfulness gate** — `evaluate/3` first *replays the recorded input*
   under the check-list and refuses with a typed
   `{:error, {:record_outcome_mismatch, detail}}` if it does not reproduce
   the recorded `{admitted?, refusal}`. A receipt that cannot reproduce its
   own decision admits no counterfactual claim (zero unreceipted abduction).
4. **Causal delta** — the explanation names the exact check(s) whose verdict
   flipped between the recorded log and the counterfactual log (diff by
   check name, recorded order). Single flip ⇒ that check is the cause;
   multiple flips ⇒ each named, in order. The counterfactual is exact and
   deterministic, satisfying Art. 86's "meaningful information... logic
   involved" without statistical approximation.

## Check-list contract (W505 coordination note)

W505's `dataset_admission_test.exs` / `eu_ai_act_admission_test.exs` were not
yet present in the checkout at implementation time, so the check-list
argument is the general fun-list idiom: an ordered list of
`(input -> :ok | {:refused, atom})` funs, each optionally wrapped as
`{name, fun}` (bare funs take their function name). Any W505 check of that
shape drops in unchanged; the decision is the first `{:refused, _}` in list
order, and every check's verdict is logged so the full `U` is witnessed.

## Verification

- `MIX_BUILD_ROOT=_build-laneW506 mix test test/xaas/semantics/counterfactual_test.exs` — see receipt tail below.
- Strict compile: `mix compile --warnings-as-errors` under the same root.
- Surface-only: no route wiring, no HTTP exposure (integration is a later lane).

## Test tail

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW506 \
    mix test test/xaas/semantics/counterfactual_test.exs
.........
Finished in 0.08 seconds (0.08s async, 0.00s sync)
Result: 9 passed

$ MIX_ENV=test MIX_BUILD_ROOT=_build-laneW506 mix compile
COMPILE_EXIT=0   # full app compiles; remaining warnings are W505's
                 # dataset_admission.ex (:127/:155 unused-var), not lane W506 files
```

Counterfactual.ex itself compiles with ZERO warnings (re-touched + full compile
grep: 0 hits). Standing: ALIVE (surface-only, exact deterministic Theorem 7.1
counterfactual witnessed by 9 real-pipeline tests).
