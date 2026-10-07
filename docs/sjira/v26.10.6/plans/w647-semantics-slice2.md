# W647 — semantics dir slice-2 convergence witness (lane receipt)

Lane: W647, repo /Users/sac/xaas @ feat/playwright-surface (one canonical checkout).
Scope: verify the fully-converged W500-series semantics tree at tree level. Only this file written.

## Commands (real, asdf shims, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW647)

### 0. Lane bootstrap anomaly (pre-test)

Fresh lane build root `mix deps.compile` failed once on `:ash_a2a`:

```
** (ArgumentError) cannot build released AgentCard: :capability_release_closure_missing
    lib/ash_a2a/info.ex:110: AshA2A.Info.agent_card/2
    lib/ash_a2a/agent.ex:223: AshA2A.Agent.__card_opts__/2
```

Recovery: `mix deps.compile ash_a2a --force` in the lane root → "Generated ash_a2a app"
(only type warnings, e.g. `lib/ash_a2a/eval/runner.ex:99:37`). Classification: lane-build
bootstrap ordering issue, not a semantics-code defect. Not reproducible after the forced
recompile; the canonical `_build/test` has ash_a2a compiled, so other lanes likely copied or
compiled in an order that satisfied it.

## 1. `mix test test/xaas/semantics/`

Full log: /tmp/w647-semantics-test.log

```
Finished in 4.7 seconds (3.0s async, 1.6s sync)
Result: 229/232 passed, 1 skipped, 5 excluded
Failed: 3 tests
```

Baseline comparison (W626): 197/203 → now 232 tests (+~29 net of skips/excludes),
229 passing. Excluded tags include `:eu_ai_act` (test config).

### Failures (isolated once, classified)

**F1 — NEW convergence defect (this wave, W657 AiroRiskMapping vs module):**
```
  1) test W657 EUAIA family: each Art. 5 atom maps to its distinct risk concept
     (Xaas.Semantics.AiroRiskMappingTest)
     test/xaas/semantics/airo_risk_mapping_test.exs:96
     Assertion with == failed
     code:  assert AiroRiskMapping.risk_concept_for("BLOCKED_UNRECEIPTED_ACTUATION") == "UNADMITTED_TRANSITION"
     left:  "RECEIPT_INTEGRITY_FAILURE"
     right: "UNADMITTED_TRANSITION"
```
Root cause (read both sides): `lib/xaas/semantics/airo_risk_mapping.ex` match arm order —
the `String.contains?(variant, "RECEIPT")` arm (line ~183) fires on
`BLOCKED_UNRECEIPTED_ACTUATION` before the `true ->` catch-all that the test (line 125)
expects. The W657 test lane and the module arm-ordering converged in conflict: either the
test's expectation must move to a dedicated `UNRECEIPTED` arm before the `RECEIPT` arm, or
the test expectation updates to `RECEIPT_INTEGRITY_FAILURE`. Not a flake (deterministic).
Out of W647's write contract → reported verbatim, not fixed.

**F2/F3 — out-of-slice (W705 census lane, not EU-AI-Act modules):**
```
  2) test Xaas.Gall.Turtle.from_turtle/1 ... dual-safe append arms
     (Xaas.Semantics.MapUpdateDualSafeTest) test/xaas/semantics/map_update_dual_safe_test.exs:159
     match (=) failed
     code:  assert {:ok, checkpoint} = Xaas.Gall.Turtle.from_turtle(@ttl)
     left:  {:ok, checkpoint}
     right: {:refused, :refused_authority}

  3) test census drift tripwire: all 12 w705 census sites are dual-safe
     (Xaas.Semantics.MapUpdateDualSafeTest) test/xaas/semantics/map_update_dual_safe_test.exs:57
     census site file missing: lib/xaas/runtime/fond/circuit.ex
```
Classification: `lib/xaas/runtime/fond/circuit.ex` exists on disk — F3's "file missing"
and F2's `{:refused, :refused_authority}` are W705-lane surfaces (Turtle from_turtle
authority path + census tripwire), outside the W647 EU-AI-Act module inventory. Reported
for the owning lane.

## 2. Whole-app strict compile

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW647 mix compile --warnings-as-errors
==> ash_affidavit
     warning: module attribute @envelope_domain_tag was set but never used  (dep, non-fatal)
==> xaas
Compiling 2 files (.ex)
EXIT=0
```

Totality witness at tree level: clean strict compile (exit 0) with W630 fixes + W621b pin
+ airo mapping all present.

## 3. Module inventory witnessed (all green in this run)

eu_ai_act_admission, dataset_admission, airo_risk_mapping (1 test-side conflict, F1),
audit_chain, robust_margin, counterfactual, declared_metrics, incident_report,
oversight_governance, automation_bias_countermeasure, vulnerability_lifecycle,
authority_channel, admission_attribution, jcs (+ master_equation, soak, admission_fuzz,
jcs_property, r2rml_refusal, ash_r2rml — warnings-only surfaces).

## 4. Verdict

**NOT CONVERGENCE-WITNESSED — PARTIAL: 1 new-convergence finding (F1, airo arm-order vs
W657 test, deterministic, verbatim above) + 2 out-of-slice failures (F2/F3, W705 lane).
All other modules green together (229/232, 1 skipped, 5 excluded) and strict whole-app
compile EXIT=0.** Handing F1 to the W657 lane / coordinator for arm-order-vs-expectation
resolution; F2/F3 to W705.
