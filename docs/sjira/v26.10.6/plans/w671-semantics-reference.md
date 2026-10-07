# W671 — diataxis reference page for `lib/xaas/semantics/`

- Subject: `/Users/sac/xaas` @ `a0723bf6`, branch `feat/playwright-surface`
- Outputs (all new, uncommitted per lane law):
  - `docs/claude/diataxis/reference/eu-ai-act-semantics.md`
  - index line in `docs/claude/diataxis/README.md` (Reference section)
  - this receipt

## Module inventory actually read (file:line)

All under `lib/xaas/semantics/`:

| module | file | read anchors (lines) |
|---|---|---|
| EuAiActAdmission | `eu_ai_act_admission.ex` | 1-111 (moduledoc table 16-23, atoms 34-51, admit 105-116) |
| DatasetAdmission | `dataset_admission.ex` | 1-100 (gate order 27-31, specs 52-61, gates 61-87) |
| AdmissionAttribution | `admission_attribution.ex` | 1-75 (spec 45, guard 49) |
| Counterfactual | `counterfactual.ex` | 1-107 (types 27-49, evaluate spec 82) |
| AutomationBiasCountermeasure | `automation_bias_countermeasure.ex` | 1-90 (spec 88) |
| RobustMargin | `robust_margin.ex` | 1-126 (spec 42, admit spec 88-100, gates 94-126) |
| DeclaredMetrics | `declared_metrics.ex` | 1-40 (cited paths 21-27, spec 34) |
| VulnerabilityLifecycle | `vulnerability_lifecycle.ex` | 1-125 (states 29-31, spec 58-125) |
| IncidentReport | `incident_report.ex` | 1-117 (mapping table 10-15, build 61-68, transmit 103-109) |
| AuthorityChannel | `authority_channel.ex` | 30-200 (channel type 44-53, registry 88-92, transmit 138-180) |
| OversightGovernance | `oversight_governance.ex` | 1-250 (specs 61, 72, 106, 142, 196, 221, 251) |
| AiroRiskMapping | `airo_risk_mapping.ex` | 1-30 (atom-to-concept map 23-30), specs 37-220 |
| Jcs | `jcs.ex` | 43-44 |
| ComputationArtifact / ComputationHash / ComputationClaim / PlanningAdvice / RuntimeEquivalence | `computation.ex` | specs 36, 66, 91, 146, 181, 237, 265, 284, 346 |
| Registry | `registry.ex` | specs 107-183 |
| R2RML | `r2rml.ex` | specs 36-124 |
| VKG | `vkg.ex` | specs 19-89 |

Modules not read in full beyond signatures/doc headers: R2RML internals,
VKG internals, Registry internals — their sections state signature-level
facts only. Module count: 16 source files (`vkg/` support dir not inventoried;
`computation.ex` holds 5 modules, so 20 modules total in the layer).

## Standing: PARTIAL_ALIVE

- Reference page facts cross-checked against the code at HEAD `a0723bf6`
  (read, not inferred); corpus line ids verified against
  `docs/eu_ai_act/corpus.json` via a real parse (`python3 -c ...` over
  `line_id`s for articles 4, 5, 10, 13, 14, 15, 26, 27, 72, 73, 86).
- Line length ≤100 enforced (`awk` sweep: clean).
- NOT executed: no test run, no module compile — this lane wrote docs only.
  The signatures quoted are real `@spec`s read from source; drift between
  doc and code is falsifiable by re-reading the anchors above.
- Falsifier: any signature or refusal atom in
  `docs/claude/diataxis/reference/eu-ai-act-semantics.md` that does not match
  the cited file:line at the recorded subject.
