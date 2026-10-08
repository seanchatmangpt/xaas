# W984gq — docs deepening: eu-ai-act-semantics.md corpus-court citations

Lane W984gq · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; **no commit** per
dispatch). Docs-only lane: no build root, no `lib/` or `test/` edits.

## What landed

One new section appended to
`docs/claude/diataxis/reference/eu-ai-act-semantics.md` (before `## See Also`):
"Corpus deepening courts (Landed 2026-10-07)" — one row per deepening suite
landed this wave (art9x, art10_2e_art26_4, art11_1_art12x, art13x, art14x,
art15x, art26x, all `test/eu_ai_act/`), each citing articles/lines covered,
the real repo seam, and the owning receipt
(`w984fc/ev/ew/ey/fa/fb/ec-probe.md`).

## Code verification (real greps, this session)

Every cited seam verified on disk before citing:

- `AiroRiskMapping.risk_graph/0` — `lib/xaas/semantics/airo_risk_mapping.ex:236`
- `Telemetry.OcelNdjson.validate_ndjson_file/1` — `lib/xaas/telemetry/ocel_ndjson.ex:112`
- `Xaas.Witness.AuditChain` — `lib/xaas/witness/audit_chain.ex` (exists)
- `Xaas.Ultracode.Ocel.Validator` — `lib/xaas/ultracode/ocel/validator.ex` (exists)
- `AdmissionAttribution.shapley/2` — `lib/xaas/semantics/admission_attribution.ex:47`
- `Counterfactual.evaluate/run` — `lib/xaas/semantics/counterfactual.ex:84,128`
- `Xaas.Actuation.QuiescentStop` — `lib/xaas/actuation/quiescent_stop.ex:1`
- `RobustMargin.admit/4` — `lib/xaas/semantics/robust_margin.ex:94`
- `GraphlawWasm.judge_imports/2` — `lib/xaas/semantics/graphlaw_wasm.ex:174`
- `IncidentReport.build/2` — `lib/xaas/semantics/incident_report.ex:70`
- `EuAiActAdmission.admit/1` — `lib/xaas/semantics/eu_ai_act_admission.ex:118`

## Correction vs dispatch

The dispatch's six receipts (fc/ev/ew/ey/fa/fb) cover six of the seven
suites; the seventh (`art10_2e_art26_4_dataset_purpose_deepening_test.exs`)
is owned by `w984ec-probe.md` (verified via the test's own `@moduledoc` and
grep over the plans dir), cited as such.

## Status

Docs-only landing, `lib/` untouched, no commit. No test run (docs-only per
dispatch). Standing: PARTIAL_ALIVE as a docs surface; the cited courts are
ALIVE per their own receipts (real pass runs, census 1388 passed / 1 excluded
as of the W984ev/W984fb runs).
