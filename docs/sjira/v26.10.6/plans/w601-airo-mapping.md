# W601 — AIRo Risk Mapping Lane Receipt

Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, lane W601, private build root `_build-laneW601`.

## Scope

Map the fleet's typed refusal surfaces to AIRo risk vocabulary: the refusal ledger becomes a
machine-readable risk graph.

Files (contract-bounded):

- `lib/xaas/semantics/airo_risk_mapping.ex` — `Xaas.Semantics.AiroRiskMapping`
- `test/xaas/semantics/airo_risk_mapping_test.exs`
- this receipt

## Dependency

`priv/semantic/airo/airo.ttl` (W600) present at lane start — no polling needed. Verified terms
used from it: `RiskSource`, `Hazard`, `RiskControl`, `AISystem`, `AIDeployer`, `hasRisk`,
`hasRiskControl`, `isRiskSourceFor`, `isRiskControlFor`, `detectsRiskConcept`,
`mitigatesRiskConcept`, `isDeployedBy` (all confirmed present in the ontology by grep).

## Mapping table (refusal family → minted risk concept)

Deterministic function `risk_concept_for/1` of the variant string:

| refusal family (substring) | risk concept |
|---|---|
| AUTHORITY / AMBIENT | `ex:AUTHORITY_ESCAPE` |
| CASTLE+IDENTITY | `ex:IDENTITY_SPOOFING` |
| DIGEST / HASH | `ex:RECEIPT_DIGEST_MISMATCH` |
| RECEIPT / AUDIT | `ex:RECEIPT_INTEGRITY_FAILURE` |
| PROJECTION / SEMANTIC | `ex:SEMANTIC_PROJECTION_DRIFT` |
| VKG | `ex:KNOWLEDGE_GRAPH_SURFACE_EXPOSURE` |
| CHECKPOINT | `ex:CHECKPOINT_STATE_CORRUPTION` |
| EVIDENCE | `ex:EVIDENCE_INTEGRITY_FAILURE` |
| ADAPTER / PROFILE | `ex:ADAPTER_PROFILE_DRIFT` |
| TOKEN / IDEMPOTENCY | `ex:REPLAY_OR_IDEMPOTENCY_FAILURE` |
| BUDGET / CAPACITY | `ex:RESOURCE_EXHAUSTION` |
| CHICAGO / JSON | `ex:PROTOCOL_SHAPE_MISMATCH` |
| EXECUTION / INTENT | `ex:UNADMITTED_EXECUTION_INTENT` |
| fallback | `ex:UNADMITTED_TRANSITION` |

Minted concepts are `ex:`-qualified (xaas namespace), not `airo:` — the AIRo 1.0 file in-tree
carries the structural risk vocabulary only; no AIRo concrete risk-concept class is fabricated.

## RiskControls (enforcing seams, path-verified on disk)

| module | path | detects |
|---|---|---|
| Xaas.Semantics.EuAiActAdmission | lib/xaas/semantics/eu_ai_act_admission.ex | UNADMITTED_SEMANTIC_ADMISSION |
| Xaas.Semantics.DatasetAdmission | lib/xaas/semantics/dataset_admission.ex | TRAINING_DATA_QUALITY_DRIFT, BIASED_OR_UNREPRESENTATIVE_DATA |
| Xaas.Semantics.RobustMargin | lib/xaas/semantics/robust_margin.ex | ROBUSTNESS_MARGIN_EXHAUSTION |
| Xaas.Witness.AuditChain | lib/xaas/witness/audit_chain.ex | AUDIT_TRAIL_BREAK, RECEIPT_REPLAY_FAILURE |
| Xaas.Actuation.QuiescentStop | lib/xaas/actuation/quiescent_stop.ex | UNCONTROLLED_ACTUATION |
| Xaas.Semantics.VulnerabilityLifecycle | lib/xaas/semantics/vulnerability_lifecycle.ex | UNPATCHED_VULNERABILITY, CYBERATTACK_EXPOSURE |
| Xaas.Castle | lib/xaas/castle.ex | UNRECEIPTED_ACTUATION, CASTLE_AUTHORITY_ESCAPE |
| XaasWeb.Plugs.RequireInternalApiToken | lib/xaas_web/plugs/require_internal_api_token.ex | UNAUTHENTICATED_API_ACCESS |

## Graph shape

- 63 `ex:riskSource-*` nodes, each `a airo:RiskSource, airo:Hazard` (62 `REFUSED_*` +
  1 `BLOCKED_CASTLE_TRANSPORT`; the ledger's own `counts.declared` says 62 — the 63rd entry is
  the BLOCKED variant, disclosed here).
- 8 `ex:riskControl-*` nodes with `airo:detectsRiskConcept` / `airo:mitigatesRiskConcept`.
- `ex:xaas-system a airo:AISystem` with 63 `airo:hasRisk` edges + `airo:hasRiskControl` edges +
  `airo:isDeployedBy ex:xaas-deployer` (`airo:AIDeployer`).
- Deterministic: ledger order sorted; output byte-identical across runs (tested ×2).

## Emission sample

```turtle
ex:riskSource-BLOCKED_CASTLE_TRANSPORT a airo:RiskSource, airo:Hazard ;
  rdfs:label "BLOCKED_CASTLE_TRANSPORT" ;
  airo:isRiskSourceFor ex:xaas-system ;
  ex:enforcingModule "lib/xaas/castle.ex:950"^^xsd:string ;
  ex:refusalVariant "BLOCKED_CASTLE_TRANSPORT"^^xsd:string ;
  ex:refusedType "BLOCKED"^^xsd:string ;
  ex:mapsToRiskConcept ex:UNADMITTED_TRANSITION .
```

## Verification (real output)

- `MIX_BUILD_ROOT=_build-laneW601 MIX_ENV=test mix compile` → exit 0 (warnings only,
  pre-existing e.g. `AshAffidavit.Signing` unused attribute).
- `MIX_BUILD_ROOT=_build-laneW601 MIX_ENV=test mix test test/xaas/semantics/airo_risk_mapping_test.exs`:

```
....
Finished in 0.2 seconds (0.2s async, 0.00s sync)

Result: 7 passed
```

- rdflib round-trip (via `/tmp/airo-venv` venv, rdflib 7.6.0, run inside the test):
  `TRIPLES=642` — the emitted graph parses as real Turtle.
- Node count: 63 risk sources + 8 controls + 1 system + 1 deployer = 73 subject nodes.

## Session note

Mid-lane, the module file was concurrently overwritten on this shared checkout (once to a
SyntaxError form that briefly blocked W551's compile, then to an equivalent parseable form).
The current on-disk version parses and all lane gates are green against it; the test suite
locks the behavior either way.
