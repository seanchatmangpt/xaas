# W624 — Counterfactual Harness Extension (EU AI Act wave)

Lane W624, repo `xaas` @ `feat/playwright-surface`, build root `_build-laneW624`.
Extends `test/eu_ai_act/counterfactual_test.exs` (W550's 17 tests intact) with
new paired factual → do-intervention → deterministic-refusal rows over real
in-repo modules. Contract respected: only the test file and this receipt were
written.

## New row table

| # | Article | Seam (real module) | Factual baseline | do-intervention | Asserted outcome | Status |
|---|---------|--------------------|------------------|-----------------|------------------|--------|
| 1 | Art 9(2)(a) | ferroplan BackwardSafeSet — NOT a xaas dep | — | — | — | **NOT_RUN (disclosed)**: cross-repo; no in-repo seam for a real call |
| 2 | Art 11 | `Xaas.Semantics.DeclaredMetrics.declare/0` | real receipt corpus read, `{:ok, map}` | `:declared_metrics_root` → empty dir (all cited sources gone) | `{:error, :REFUSED_METRICS_SOURCE_MISSING}` ×2 identical | PASS |
| 3 | Art 25 | `Xaas.Semantics.Jcs.encode/1` + `Xaas.Witness.AuditChain.hash_receipt/2` | digest of lawful payload / chain hash of lawful link | tamper exactly one nested field / one `payload_digest` | digest changes (`d != factual`), deterministic ×2 | PASS |
| 4 | Art 26(6) | `Xaas.Semantics.OversightGovernance.retention_policy/0` + `cited_paths/0` + `AuditChain` tamper (W524b in-memory pattern) | policy = `:permanent_durable_rows`, all cited paths exist; 3-link chain verifies | tamper link k=1 `payload_digest` | `{:error, {:tampered, 1}}` ×2 identical; lawful chain still verifies | PASS |
| 5 | Art 50(2) | `XaasWeb.Plugs.SyntheticMarkingPlug` (real plug dispatch + before_send) | 200 JSON body carries header + `"ai_generated": true`; refusal envelope also marked | strip `ai_generated` from body; re-dispatch through plug | strip is DETECTABLE: plug re-marks unconditionally; byte-identical ×2 | PASS |
| 6 | Art 72 | Definition 7.2 token-replay fitness (inline replica; cited from `test/xaas/telemetry/ocel_fitness_integration_test.exs` W545, whose `Art72` submodule is not compiled in the `test/eu_ai_act` context) | real event sequence `prepare → actuate → seal` scores fitness 1.0 / `:NO_DRIFT` | drop exactly the `sealed_receipt` event | fitness < 1.0, `:DRIFT`, `missing > 0`, ×2 identical | PASS |
| 7 | Art 14(4)(b) | `Xaas.Semantics.AutomationBiasCountermeasure.briefing/2` over a REAL refusal (`QuiescentStop` → `:REFUSED_STOP_AUTHORITY`) | — (real refusal record built from the Art 14(4)(e) fail-closed seam) | the refusal itself is the observed event; countermeasure applied | `verdict == :refuse`, `refusal_anatomy != []`, ×2 identical | PASS |

## Determinism

Every intervention row ran twice with identical results (asserted in-test,
`r2 == r1` / byte-identical bodies).

## Verification

```
MIX_BUILD_ROOT=_build-laneW624 mix test test/eu_ai_act/counterfactual_test.exs
```

Result recorded in the lane report (W550's 17 + W624's 7 = green total there).

## Scoping honesty

- Art 9(2)(a): NOT_RUN — ferroplan is cross-repo, no in-repo seam. Not
  silently dropped; no OCEL-fitness proxy claimed for it (proxy rejected).
- Art 72: inline calculus replica, disclosed above; not claimed as a call
  into W545's module.
