# W984hr — semantics root unclaimed-family probe (lane receipt)

Date: 2026-10-07 · Branch `feat/playwright-surface` (shared canonical checkout, no commit)
Lane build root: `_build-laneW984hr` (removed at integration — see cleanup)

## Scope census

Root modules of `lib/xaas/semantics/*.ex` (13 files, excluding courted subfamilies
airo_risk_mapping, vkg/ + vkg.ex, graphlaw_wasm, incident_report, oversight_governance):

| module | lines | direct test files | disposition |
|---|---|---|---|
| admission_attribution.ex | 142 | admission_attribution_test, attribution_counterfactual_depth_test, counterfactual_deepening_test, master_equation_* , title_iii_test | COVERED (incl. COALITION_LIMIT boundary, bad-verdict ArgumentError, efficiency property) |
| authority_channel.ex | 310 | authority_channel_test, authority_channel_incident_witness_test, art73/art86/art99 deepening | COVERED (both typed refusals have 7 test hits each) |
| automation_bias_countermeasure.ex | 167 | automation_bias_countermeasure_test, title_iii_test, counterfactual_deepening_test, art_14_4b | PARTIALLY COVERED → courted: `{:refusal_missing_reason, checks}` had 0 test hits |
| computation.ex (4 modules: ComputationArtifact/ComputationClaim/PlanningAdvice/RuntimeEquivalence) | 482 | semantics_computation_test, computation_doctest_test, sa2a_* | PARTIALLY COVERED → courted: PlanningAdvice `:planning_advice_cannot_authorize_actuation`, `:planning_advice_standing_refused`, `:planning_advice_candidate_refs_must_be_unique`, `:invalid_planning_advice_candidate`, `:formal_candidate_refs_must_be_unique`(2 hits, indirect only), order_formal remainder-append; RuntimeEquivalence `:tolerance_must_be_non_negative`, `:invalid_runtime_equivalence_input`, `:output_key_set_mismatch` all had 0 test hits |
| counterfactual.ex | 245 | counterfactual_test, counterfactual_doctest_test, counterfactual_deepening_test, art86 | COVERED |
| dataset_admission.ex | 267 | dataset_admission_test, art15/title_ii/title_iii deepening | COVERED (all four typed refusals exercised) |
| declared_metrics.ex | 112 | declared_metrics_test + declared_metrics_staleness_test | COVERED — staleness court already covers present-but-unparseable, malformed JSON, wrong shape, regex miss, missing mutation receipts, drift typing |
| eu_ai_act_admission.ex | 228 | eu_ai_act_admission_test, eu_ai_act_refusal_closed_set_test, 25-file eu_ai_act family | COVERED (all 8 refusal atoms courted) |
| jcs.ex | 63 | jcs_test, jcs_property_test, jcs_doctest_test | COVERED (facade over pinned `jcs` hex; doctests + property) |
| r2rml.ex | 283 | ash_r2rml_test, r2rml_refusal_test, vkg family courts | COVERED |
| registry.ex | 272 | registry_test (walks every configured Ash resource via admit/1 + hash stability), r2rml_refusal_test, actuation_test, fibo court | COVERED (all-Resource admit walk exercises every classes_for/predicate branch; rescue + fallback branches exercised by the Resource sweep) |
| robust_margin.ex | 3 named refusals | robust_margin_test, robust_margin_depth_test, art15/title_ii deepening | COVERED (7-8 hits per refusal atom) |
| vulnerability_lifecycle.ex | 139 | vulnerability_lifecycle_test, art_15_5s3 real-detection test, title_iii | COVERED (all 3 refusals courted) |

## Courts added

`test/xaas/semantics/root_court_w984hr_test.exs` — 11 tests, real collaborators
(real structs, real atoms, no mocks, no interaction assertions), one mutation
rationale per test:

1. AutomationBiasCountermeasure `{:refusal_missing_reason, checks}` — refusal
   recorded without a reason must refuse typed.
2. AutomationBiasCountermeasure `{:refusal_mismatch, ...}` — first-fail refusal
   atom differing from the recorded refusal must refuse typed.
3. Typed COVERED census for the three sibling guards (already courted at
   automation_bias_countermeasure_test.exs:154 and title_iii_test).
4. PlanningAdvice `:planning_advice_cannot_authorize_actuation` — advice cannot
   mint DO authority.
5. PlanningAdvice `{:planning_advice_standing_refused, "AUTHORITY"}` — standing
   forgery refused.
6. PlanningAdvice `:planning_advice_candidate_refs_must_be_unique` — double-scored
   candidate refused.
6bis. PlanningAdvice `:invalid_planning_advice_candidate` — normalized candidate
   guard (empty ref / non-numeric score), two shapes.
7. order_formal/2 remainder append — advice cannot silently prune formal
   candidates it never scored.
8. RuntimeEquivalence `:tolerance_must_be_non_negative`.
9. RuntimeEquivalence `:invalid_runtime_equivalence_input` (non-map reference /
   candidate).
10. RuntimeEquivalence `:output_key_set_mismatch` — candidate output key-set
    mismatch is a typed non-pass result, not a KeyError crash.

## Gates (real commands, real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984hr
  mix test test/xaas/semantics/root_court_w984hr_test.exs`
  → `Result: 11 passed` (exit 0), after one real fix: ComputationArtifact
  requires an admitted runtime (from `~w(ONNX NX AXON PYTORCH SCIKIT_LEARN LLM
  RULE SPARQL FOND HDDL NATIVE WASM HUMAN)`); "BEAM" was refused
  `{:unsupported_runtime, "BEAM"}` — fixture corrected to "NX".
- Mock gate: `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'`
  → `[]`, exit 0.
- Mid-run transport failure: another lane's in-flight edit to
  `lib/xaas/eds/falsifier.ex` briefly broke shared compile (SyntaxError 91:7);
  self-resolved within the compile-freeze SLA window (retried after 5 min,
  compiled clean). No cross-lane edit made by this lane.

## Cleanup

- `rm -rf _build-laneW984hr` attempted at integration: SUCCEEDED (`rm exit=0`;
  post-check `ls -d _build-laneW984hr` → "No such file or directory"). shutil
  fallback not needed.