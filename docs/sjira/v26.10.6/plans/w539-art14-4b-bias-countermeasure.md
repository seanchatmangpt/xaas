# W539 — Art. 14.4.b Automation-Bias Countermeasure (Mandatory Causal-Anatomy Presentation)

Lane: W539, EU-AI-Act wave, repo /Users/sac/xaas @ feat/playwright-surface.
Build root: `_build-laneW539` (lease; coordinator deletes at integration).

## Theorem mapping (Art. 14.4.b → structural countermeasure)

Art. 14.4.b requires that natural persons using a high-risk AI system can
correctly interpret its output and are aware of automation bias. The surface
implements this as a **structural** countermeasure: every admission decision
arrives with its full causal anatomy, so blind acceptance is impossible by
construction — the operator never sees an unexplained verdict.

- **Mandatory presentation (the over-reliance countermeasure)**: the briefing
  is emitted for EVERY decision, including full admits — admits list every
  check green with its (zero) Shapley attribution; refusals additionally name
  the exact flipped checks (`refusal_anatomy`).
- **Awareness = causal anatomy**: `per_check_causes` carries, per check in
  causal order: verdict, refusal, and exact Shapley blame from W505
  (`AdmissionAttribution.shapley/2`, dissertation Def 5.2, Art. 13).
- **Deterministic interpretability**: `interpretability` is the fixed string
  "counterfactual replay + exact Shapley attribution — deterministic,
  receipt-backed" — grounded by W506 (`Counterfactual`): the record carries
  the full ordered per-check log (recovered structural recourse variables),
  so `Counterfactual.evaluate/3` replay is computable from the receipt alone;
  `counterfactual_available: true` witnesses that.
- **Faithful-witness gate**: a record whose `admitted?`/`refusal`/check log
  contradict each other gets a typed refusal
  (`{:admit_with_refusal, _}`, `{:refusal_without_failing_check, _}`,
  `{:refusal_mismatch, _}`) — no silent presentation of an incoherent
  receipt (Art. 14 gate behavior, fail-closed).

## Files (lane contract)

- `lib/xaas/semantics/automation_bias_countermeasure.ex` — `Xaas.Semantics.AutomationBiasCountermeasure.briefing/2`
- `test/xaas/semantics/automation_bias_countermeasure_test.exs` — 8 tests
- this receipt

100% handwritten (no generator profile exists for this surface;
UNSUPPORTED(generator-capability) would apply, none was invoked — pure stdlib
composition of W505/W506, no app deps).

## Tests (falsifiers)

1. Refuse-case: `refusal_anatomy` names the exact flipped check
   (`human_oversight`), which carries the full −1.0 Shapley blame; passing
   checks carry 0.0.
2. Admit-case: briefing emitted with all checks green, zero attributions,
   empty `refusal_anatomy` — the structural claim tested directly.
3. Composition: real W505 (`shapley/2`) + real W506 (`run/2`, `evaluate/3`)
   over the same check list; the briefing's `refusal_anatomy` names exactly
   the checks the counterfactual replay shows flipped.
4. Determinism: same record + attributions ⇒ `==`-equal and
   `term_to_binary`-identical briefings.
5. Incoherent-record typed refusals (admit-with-refusal;
   refusal-without-failing-check).
6. `counterfactual_available` degrades to `false` when the attribution map
   does not cover the check log.

## Verification (real commands, pinned toolchain elixir 1.20.2-otp-28)

    export PATH=$HOME/.asdf/shims:$PATH
    MIX_BUILD_ROOT=_build-laneW539 mix compile --warnings-as-errors
    MIX_BUILD_ROOT=_build-laneW539 mix test test/xaas/semantics/automation_bias_countermeasure_test.exs

(actual outputs appended below at run time)

Observed 2026-10-06, pinned toolchain (asdf elixir 1.20.2-otp-28):

- `mix compile --warnings-as-errors` (whole app, `_build-laneW539`): exit 0,
  no warnings in lane files. Pre-existing dep warning only
  (`lib/ash_affidavit/signing.ex:312` type warning — not lane W539).
- `mix test test/xaas/semantics/automation_bias_countermeasure_test.exs`:
  `8 passed, 0 failures` (real output).
- `mix test test/xaas/semantics/`: `167 passed, 0 failures` (real output).

## Standing

ALIVE on exact subject `feat/playwright-surface` lane W539 (build root
`_build-laneW539`): strict compile exit 0, lane suite 8/8, semantics dir
167/167 — real outputs above.
