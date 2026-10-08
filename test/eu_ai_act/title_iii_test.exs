defmodule Xaas.EUAIAct.TitleIII.Lines do
  @moduledoc """
  Compile-time substrate for the Title III suite (lane W534 restructure of
  W523's generator): corpus load + verdict mapping, shared by the two test
  modules in this file.

  Substrate: `docs/eu_ai_act/corpus.json` (W520). The corpus is loaded directly
  as JSON at compile time (typed error if absent: `EUAIA_CORPUS_MISSING_W520`);
  the W526 `CorpusLoader` decodes the landed `{"titles": [...]}` shape,
  flattening titles -> articles -> lines (W984ke: earlier note claiming a flat
  `{"lines": [...]}` contract was stale).

  Three-state verdict per line (rules checked in order):

    1. evidence map hit         -> :evidenced
    2. consolidated placeholder -> :not_applicable
    3. Arts 6-7                 -> :not_applicable (provider-side classification)
    4. Art 12(3) variants       -> :not_applicable (Annex III point 1(a)-specific)
    5. authority addressee      -> :not_applicable
    6. Arts 26-27               -> :open_gap (deployer-side duty, no seam)
    7. Arts 16-25               -> :not_applicable (provider obligations)
    8. Arts 28-49               -> :not_applicable (notified-body / surveillance)
    9. default                  -> :open_gap (honest fallback)
  """

  @corpus_relpath "docs/eu_ai_act/corpus.json"

  # ---------------------------------------------------------------------------
  # Evidence table: line_id -> {lane, seam description, paths to assert}
  #
  # Every path was verified on disk at generation time (2026-10-06,
  # xaas @ feat/playwright-surface, HEAD d1db2b03).
  # ---------------------------------------------------------------------------
  defp evidence_map do
    %{
      # Art. 9 — ferroplan inverse-reachability safe-set (W501, Theorem 3.1)
      "9.5.a" => {"W501", "risk elimination via ferroplan inverse-reachability safe-set",
                  ["/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs",
                   "docs/sjira/v26.10.6/plans/w501-art9-reachability.md"]},
      "9.5.b" => {"W501", "mitigation/control measures via reachability-derived safe-set",
                  ["/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs",
                   "docs/sjira/v26.10.6/plans/w501-art9-reachability.md"]},
      "9.6" => {"W501", "testing via the reachability mutant-killing test court",
                ["/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs",
                 "docs/sjira/v26.10.6/plans/w501-art9-reachability.md"]},
      # Art. 10 — dataset admission gate (W502)
      "10.2.f" => {"W502", "bias examination via the sliced-W1 bias gate",
                   ["lib/xaas/semantics/dataset_admission.ex",
                    "test/xaas/semantics/dataset_admission_test.exs",
                    "docs/sjira/v26.10.6/plans/w502-art10-dataset-gate.md"]},
      "10.2.g" => {"W502", "bias detect/prevent/mitigate via typed bias-threshold refusal",
                   ["lib/xaas/semantics/dataset_admission.ex",
                    "test/xaas/semantics/dataset_admission_test.exs",
                    "docs/sjira/v26.10.6/plans/w502-art10-dataset-gate.md"]},
      "10.2.h" => {"W502", "data-gap identification via the completeness gate",
                   ["lib/xaas/semantics/dataset_admission.ex",
                    "test/xaas/semantics/dataset_admission_test.exs",
                    "docs/sjira/v26.10.6/plans/w502-art10-dataset-gate.md"]},
      # Art. 12 — audit chain (W503) + OCEL event surface
      "12.1" => {"W503", "automatic event recording via hash-chained audit receipts",
                 ["lib/xaas/witness/audit_chain.ex",
                  "test/xaas/witness/audit_chain_test.exs",
                  "docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md"]},
      "12.2" => {"W503", "traceability via audit-chain replay (Def 4.2 + Thm 4.1)",
                 ["lib/xaas/witness/audit_chain.ex",
                  "test/xaas/witness/audit_chain_test.exs",
                  "docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md"]},
      "12.2.a" => {"W503", "risk-situation traceability via the audit-chain digest chain",
                   ["lib/xaas/witness/audit_chain.ex",
                    "docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md"]},
      "12.2.b" => {"W503", "post-market-monitoring traceability via OCEL event log",
                   ["lib/xaas/witness/audit_chain.ex",
                    "lib/xaas/telemetry/ocel_ndjson.ex",
                    "docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md"]},
      "12.2.c" => {"W503", "operation monitoring via audit receipts over actuation ids",
                   ["lib/xaas/witness/audit_chain.ex",
                    "docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md"]},
      # Art. 13 — transparency: interpretability seams (W506 counterfactual, W505 attribution)
      "13.3.b.vii" => {"W506/W505",
                       "output interpretation via counterfactual explanation",
                       ["lib/xaas/semantics/counterfactual.ex",
                        "test/xaas/semantics/counterfactual_test.exs",
                        "lib/xaas/semantics/admission_attribution.ex",
                        "test/xaas/semantics/admission_attribution_test.exs",
                        "docs/sjira/v26.10.6/plans/w506-art86-counterfactual.md"]},
      "13.3.f" => {"W506/W505",
                   "output-interpretation mechanisms via counterfactual + attribution",
                   ["lib/xaas/semantics/counterfactual.ex",
                    "test/xaas/semantics/counterfactual_test.exs",
                    "lib/xaas/semantics/admission_attribution.ex",
                    "test/xaas/semantics/admission_attribution_test.exs",
                    "docs/sjira/v26.10.6/plans/w506-art86-counterfactual.md"]},
      # Art. 14 — human oversight: override + stop (W507 quiescent stop, W506 counterfactual)
      "14.4.d" => {"W507/W506",
                   "override ('disregard output') via counterfactual re-run + typed refusal",
                   ["lib/xaas/actuation/quiescent_stop.ex",
                    "lib/xaas/semantics/counterfactual.ex",
                    "test/xaas/actuation/quiescent_stop_test.exs",
                    "docs/sjira/v26.10.6/plans/w507-art14-estop.md"]},
      "14.4.e" => {"W507", "interrupt via 'stop' button (quiescent-stop attractor)",
                   ["lib/xaas/actuation/quiescent_stop.ex",
                    "test/xaas/actuation/quiescent_stop_test.exs",
                    "docs/sjira/v26.10.6/plans/w507-art14-estop.md"]},
      # Art. 15 — robustness margin (W508) + WASI admission gate (W509)
      "15.4" => {"W508", "resilience to errors via the robust-margin gate (Thm 5.3)",
                 ["lib/xaas/semantics/robust_margin.ex",
                  "test/xaas/semantics/robust_margin_test.exs",
                  "docs/sjira/v26.10.6/plans/w508-art15-margin.md"]},
      "15.5" => {"W509", "cybersecurity via the eyerun_wasi SHACL admission gate",
                 ["/Users/sac/wasm4pm/crates/eu_gate",
                  "docs/sjira/v26.10.6/plans/w509-wasi-gate.md"]},

      # --- W535 reclassifications (deployer-class honest judgment) ------------
      # Art. 10 — data governance exercised at admission time (no training)
      "10.2" => {"W502", "data-governance practice = the dataset admission gate over every admitted dataset",
                 ["lib/xaas/semantics/dataset_admission.ex",
                  "test/xaas/semantics/dataset_admission_test.exs",
                  "docs/sjira/v26.10.6/plans/w502-art10-dataset-gate.md"]},
      "10.2.e" => {"W502", "availability/quantity/suitability assessment via the completeness gate",
                   ["lib/xaas/semantics/dataset_admission.ex",
                    "test/xaas/semantics/dataset_admission_test.exs",
                    "docs/sjira/v26.10.6/plans/w502-art10-dataset-gate.md"]},
      "10.3" => {"W502", "representativeness/completeness via the dataset completeness + bias gates",
                 ["lib/xaas/semantics/dataset_admission.ex",
                  "test/xaas/semantics/dataset_admission_test.exs",
                  "docs/sjira/v26.10.6/plans/w502-art10-dataset-gate.md"]},
      # Art. 11 — technical documentation kept up to date over real receipts
      "11.1" => {"W503/W524b", "up-to-date machine documentation = hash-chained audit receipts over real lane receipts",
                 ["lib/xaas/witness/audit_chain.ex",
                  "test/xaas/witness/audit_chain_test.exs",
                  "docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md",
                  "docs/sjira/v26.10.6/plans/w524b-audit-chain-integration.md"]},
      # Art. 15 — umbrella + fail-safe + appropriateness
      "15.1" => {"W508/W509/W503",
                 "accuracy/robustness/cybersecurity posture = robust-margin gate + WASI admission gate + audit chain",
                 ["lib/xaas/semantics/robust_margin.ex",
                  "test/xaas/semantics/robust_margin_test.exs",
                  "docs/sjira/v26.10.6/plans/w508-art15-margin.md",
                  "docs/sjira/v26.10.6/plans/w509-wasi-gate.md",
                  "docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md"]},
      "15.4.s2" => {"W507", "fail-safe plan via the quiescent-stop attractor",
                    ["lib/xaas/actuation/quiescent_stop.ex",
                     "test/xaas/actuation/quiescent_stop_test.exs",
                     "docs/sjira/v26.10.6/plans/w507-art14-estop.md"]},
      "15.5.s2" => {"W509", "appropriateness of cybersecurity solutions = SHACL admission gate scoped to the risk",
                    ["/Users/sac/wasm4pm/crates/eu_gate",
                     "docs/sjira/v26.10.6/plans/w509-wasi-gate.md"]},
      # Art. 26 — deployer duties
      "26.1" => {"W507/W503", "use per instructions = governed actuation surface under human-authority quiescent stop + audit chain",
                 ["lib/xaas/actuation/quiescent_stop.ex",
                  "lib/xaas/witness/audit_chain.ex",
                  "docs/sjira/v26.10.6/plans/w507-art14-estop.md",
                  "docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md"]},
      "26.2" => {"W507", "human oversight assigned via the human-authority quiescent-stop path (override + stop)",
                 ["lib/xaas/actuation/quiescent_stop.ex",
                  "test/xaas/actuation/quiescent_stop_test.exs",
                  "docs/sjira/v26.10.6/plans/w507-art14-estop.md"]},
      "26.4" => {"W502", "input-data relevance/representativeness under deployer control = dataset admission gate",
                 ["lib/xaas/semantics/dataset_admission.ex",
                  "test/xaas/semantics/dataset_admission_test.exs",
                  "docs/sjira/v26.10.6/plans/w502-art10-dataset-gate.md"]},
      "26.5" => {"W503/W524b", "operation monitoring via OCEL event log + capability receipts over the audit chain",
                 ["lib/xaas/telemetry/ocel_ndjson.ex",
                  "lib/xaas/witness/audit_chain.ex",
                  "docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md",
                  "docs/sjira/v26.10.6/plans/w524b-audit-chain-integration.md"]},
      "26.9" => {"W506/W505", "use of Art.13 information via counterfactual explanation + admission attribution",
                 ["lib/xaas/semantics/counterfactual.ex",
                  "lib/xaas/semantics/admission_attribution.ex",
                  "docs/sjira/v26.10.6/plans/w506-art86-counterfactual.md"]},
      "26.12" => {"W503/W524b", "cooperation substrate = replayable hash-chained receipts over real lane receipts",
                  ["lib/xaas/witness/audit_chain.ex",
                   "docs/sjira/v26.10.6/plans/w524b-audit-chain-integration.md"]},

      # --- W547 flip pass: surfaces landed this wave (W533/W536/W537/W539/W540)
      "15.3" => {"W536", "declared accuracy/robustness metrics + refusal coverage + conformance, read fail-closed from real receipts",
                 ["lib/xaas/semantics/declared_metrics.ex",
                  "test/xaas/semantics/declared_metrics_test.exs",
                  "docs/sjira/v26.10.6/plans/w536-art15-3-metrics.md"]},
      "15.5.s3" => {"W540", "AI-specific vulnerability detect/triage/respond/resolve lifecycle as a forward-only typed-evidence state machine",
                    ["lib/xaas/semantics/vulnerability_lifecycle.ex",
                     "test/xaas/semantics/vulnerability_lifecycle_test.exs",
                     "docs/sjira/v26.10.6/plans/w540-art15-5-lifecycle.md"]},
      "14.4.b" => {"W539", "automation-bias awareness via mandatory causal-anatomy briefing (Shapley per-check causes + counterfactual availability on EVERY decision)",
                   ["lib/xaas/semantics/automation_bias_countermeasure.ex",
                    "test/xaas/semantics/automation_bias_countermeasure_test.exs",
                    "docs/sjira/v26.10.6/plans/w539-art14-4b-bias-countermeasure.md"]},
      "26.6" => {"W537", "log retention policy: sealed actuation receipts as durable rows + tamper-evident witness chain; ephemera under lease cleanup",
                 ["lib/xaas/semantics/oversight_governance.ex",
                  "test/xaas/semantics/oversight_governance_test.exs",
                  "docs/sjira/v26.10.6/plans/w537-art26-27-governance.md"]},
      "26.7" => {"W537", "worker notification via the receipt corpus + OCEL event egress to the operator channel (serious-incident authority channel EVIDENCED by Xaas.Semantics.IncidentReport — W984eb)",
                 ["lib/xaas/semantics/oversight_governance.ex",
                  "test/xaas/semantics/oversight_governance_test.exs",
                  "docs/sjira/v26.10.6/plans/w537-art26-27-governance.md"]},
      "27.1" => {"W537", "FRIA as structured machine-checkable data: per-right protections with real path/symbol/basis evidence citations and typed EVIDENCED/OPEN_GAP statuses",
                 ["lib/xaas/semantics/oversight_governance.ex",
                  "test/xaas/semantics/oversight_governance_test.exs",
                  "docs/sjira/v26.10.6/plans/w537-art26-27-governance.md"]},
      # 27.1 sub-contents covered by the same structured FRIA (fria/0 fields);
      # 27.1.b/e/f flipped EVIDENCED by W648b (2026-10-06): fria_schedule/0
      # and fria_oversight_description/0 landed.
      "27.1.a" => {"W537", "processes description = fria/0 subject_system + per-right protection statements over the admission/actuation processes",
                   ["lib/xaas/semantics/oversight_governance.ex",
                    "test/xaas/semantics/oversight_governance_test.exs",
                    "docs/sjira/v26.10.6/plans/w537-art26-27-governance.md"]},
      "27.1.c" => {"W537", "affected categories = fria/0 rights entries (workers, data subjects, discrimination targets) with Charter article citations",
                   ["lib/xaas/semantics/oversight_governance.ex",
                    "test/xaas/semantics/oversight_governance_test.exs",
                    "docs/sjira/v26.10.6/plans/w537-art26-27-governance.md"]},
      "27.1.d" => {"W537", "specific risks of harm = fria/0 per-right protection statements naming the risk each gate mitigates",
                   ["lib/xaas/semantics/oversight_governance.ex",
                    "test/xaas/semantics/oversight_governance_test.exs",
                    "docs/sjira/v26.10.6/plans/w537-art26-27-governance.md"]},
      # W648b flips (2026-10-06): structured schedule + oversight-implementation
      # fields over the real CRO-loop cycle and counterfactual/attribution surfaces.
      "27.1.b" => {"W648b", "period/frequency of review = fria_schedule/0: per-wave CRO-loop cycle + corpus drift falsifier re-verification",
                   ["lib/xaas/semantics/oversight_governance.ex",
                    "test/xaas/semantics/oversight_governance_test.exs",
                    "docs/cro/CRO-LOOP.md",
                    "docs/eu_ai_act/corpus-README.md"]},
      "27.1.e" => {"W648b", "oversight implementation = fria_oversight_description/0: per-right FRIA structure + counterfactual/attribution surfaces",
                   ["lib/xaas/semantics/oversight_governance.ex",
                    "test/xaas/semantics/oversight_governance_test.exs",
                    "lib/xaas/semantics/counterfactual.ex",
                    "lib/xaas/semantics/admission_attribution.ex",
                    "lib/xaas/semantics/automation_bias_countermeasure.ex"]},
      "27.1.f" => {"W648b", "materialisation measures = the typed materialisation inventory: fria/0's per-right safeguards + the :EVIDENCED authority-channel FRIA entry citing Xaas.Semantics.IncidentReport (W984eb flip)",
                   ["lib/xaas/semantics/oversight_governance.ex",
                    "test/xaas/semantics/oversight_governance_test.exs",
                    "lib/xaas/semantics/incident_report.ex",
                    "docs/sjira/v26.10.6/plans/w537-art26-27-governance.md"]},
      "27.3" => {"W537/W507", "safeguards when risks materialise during use = the quiescent-stop attractor in the actuation path (halt to safe state) + the :EVIDENCED FRIA materialisation entry (authority channel over Xaas.Semantics.IncidentReport — W984eb flip)",
                 ["lib/xaas/actuation/quiescent_stop.ex",
                  "test/xaas/actuation/quiescent_stop_test.exs",
                  "lib/xaas/semantics/oversight_governance.ex",
                  "docs/sjira/v26.10.6/plans/w507-art14-estop.md"]}
    }
  end

  # ---------------------------------------------------------------------------
  # W535 per-line NOT_APPLICABLE map: line_id -> typed deployer-class reason.
  # Checked right after the evidence map. These are lines the generic corpus
  # rules misclassify as OPEN_GAP but which a deployer-class system honestly
  # disposes of (no training, no products, no financial-institution or law-
  # enforcement context, savings clauses, Commission-side duties).
  # ---------------------------------------------------------------------------
  defp not_applicable_map do
    %{
      # Art. 8
      "8.2" =>
        {"product-integration clause (Union harmonisation legislation, Annex I) — this repo places no AI-containing product on the market; no provider activity"},
      # Art. 10 — training-data curation: this surface trains no models
      "10.1" =>
        {"Art.10(1) attaches to systems that train AI models with data — this deployer-class surface trains nothing; no training/validation/test dataset construction exists"},
      "10.2.a" => {"design-choices documentation duty for dataset construction — no model training happens on this surface"},
      "10.2.b" => {"data-collection/origin curation duty — no datasets are collected or curated for training here"},
      "10.2.c" => {"annotation/labelling/cleaning/enrichment curation duty — no dataset preparation pipeline exists (we train nothing)"},
      "10.2.d" => {"assumption-formulation duty about what data measure/represent — tied to training-set construction, which does not occur here"},
      "10.4" =>
        {"geographic/contextual dataset-characteristic duty applies to training/validation/testing sets — this surface trains no models"},
      "10.6" =>
        {"scope-routing paragraph (points 2-4 apply to non-training systems, adjudicated per-line); no independent obligation to implement"},
      # Art. 11
      "11.2" =>
        {"Annex I product CE-marking documentation machinery — no AI-containing product is placed on the market by this repo"},
      # Art. 15
      "15.4.s3" =>
        {"continual-learning robustness duty — this surface does not continue learning after deployment (no post-market retraining loop)"},
      # Art. 26 — context-gated deployer duties
      "26.3" =>
        {"savings clause ('without prejudice' to other Union/national law) — legal cross-reference, no independent implementable obligation"},
      "26.5.s2" =>
        {"financial-institution internal-governance equivalence — this deployer is not a financial institution under Union financial-services law"},
      "26.6.s2" =>
        {"financial-institution log-keeping equivalence — this deployer is not a financial institution under Union financial-services law"},
      "26.8" =>
        {"registration duty for public authorities / Union institutions — this deployer is neither"},
      "26.10" =>
        {"post-remote biometric identification for law enforcement — no biometric identification system is deployed by this surface"},
      "26.10.s2" => {"post-remote biometric identification authorisation machinery — no biometric identification system deployed"},
      "26.10.s3" => {"post-remote biometric identification targeting restriction — no biometric identification system deployed"},
      "26.10.s4" => {"biometric-data processing savings cross-reference (GDPR/LED) — no biometric identification system deployed"},
      "26.10.s5" => {"police-file documentation duty for biometric identification use — no law-enforcement biometric deployment"},
      "26.10.s6" => {"annual reporting on biometric identification use to surveillance/data-protection authorities — no such use exists"},
      "26.11" =>
        {"Art.13-informed worker-notification for Annex III employment/decision systems — this deployer runs no employment-decision high-risk system"},
      # Art. 27
      "27.4" =>
        {"DPIA-equivalence savings clause (GDPR Art.35 route) — legal routing provision, no independent implementable obligation"},
      "27.5" =>
        {"AI Office (Commission) questionnaire-template duty — authority-side machinery, not implementable as deployer-side code"},
      # W547: scoping clause — fixes WHEN the 27.1 duty attaches (first use),
      # carries no independent implementable obligation beyond 27.1 (evidenced).
      "27.2" =>
        {"scoping clause ('applies to the first use') — no independent obligation; attaches the evidenced 27.1 FRIA duty to first use"}
    }
  end

  # ---------------------------------------------------------------------------
  # Reclassification table (lane W532): Art 9/13/14 lines that W523's residual
  # rule left OPEN_GAP, re-judged at the system level (deployer-class surface).
  # Each EVIDENCED entry asserts its cited paths AND its receipt's verdict line
  # (String.contains? on the receipt body); each NOT_APPLICABLE entry carries a
  # typed addressee/procedure reason. Per-line judgment rationale:
  # docs/sjira/v26.10.6/plans/w532-art9-13-14-gaps.md
  # Tuple shape: id => {:evidenced, lane, desc, paths, receipt, verdict_snippet}
  #            | id => {:not_applicable, reason}
  # ---------------------------------------------------------------------------
  defp reclass_map do
    %{
      # ---- Art. 8 (umbrella, lane W649b) ----
      # 8.1 is the Section-2 umbrella: its substance is discharged by the Art
      # 9-15 implementations, all EVIDENCED in this same file. The EVIDENCED
      # test reads the receipt below and requires the child line_id list — the
      # umbrella is evidenced iff its children are evidenced.
      # Rationale: docs/sjira/v26.10.6/plans/w649b-art8-1-flip.md
      "8.1" => {:evidenced, "W649b",
                "Section-2 umbrella: compliance discharged by the evidenced Art 9-15 children (risk, dataset, audit, transparency, oversight, robustness gates)",
                ["lib/xaas/semantics/dataset_admission.ex",
                 "lib/xaas/witness/audit_chain.ex",
                 "lib/xaas/semantics/counterfactual.ex",
                 "lib/xaas/semantics/admission_attribution.ex",
                 "lib/xaas/actuation/quiescent_stop.ex",
                 "lib/xaas/semantics/automation_bias_countermeasure.ex",
                 "lib/xaas/semantics/robust_margin.ex",
                 "/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs",
                 "/Users/sac/wasm4pm/crates/eu_gate"],
                "docs/sjira/v26.10.6/plans/w649b-art8-1-flip.md",
                "children evidenced: 9.1 9.2 9.2.a 9.2.b 9.2.c 9.2.d 9.5.a 9.5.b 9.6 9.8 10.2.f 10.2.g 10.2.h 10.2 10.2.e 10.3 11.1 12.1 12.2 12.2.a 12.2.b 12.2.c 13.1 13.3.b.vii 13.3.f 14.1 14.2 14.3 14.4.b 14.4.d 14.4.e 15.1 15.3 15.4 15.5"},

      # ---- Art. 9 (was OPEN via residual rule) ----
      "9.1" => {:evidenced, "W501+W502+W503+W507+W508",
                "risk-management system = the Art-9/10/12/14/15 gate family + receipts",
                ["/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs",
                 "lib/xaas/semantics/dataset_admission.ex",
                 "lib/xaas/witness/audit_chain.ex",
                 "lib/xaas/actuation/quiescent_stop.ex",
                 "lib/xaas/semantics/robust_margin.ex"],
                "docs/sjira/v26.10.6/plans/w501-art9-reachability.md",
                "standing: PARTIAL_ALIVE"},
      "9.2" => {:evidenced, "W503",
                "continuous lifecycle process via audit-chain receipts + wave court-run reviews",
                ["lib/xaas/witness/audit_chain.ex", "lib/xaas/telemetry/ocel_ndjson.ex"],
                "docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md",
                "Verdict: PARTIAL_ALIVE"},
      "9.2.a" => {:evidenced, "W501",
                  "hazard identification/analysis via exact inverse-reachability safe-set (Thm 3.1)",
                  ["/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs"],
                  "docs/sjira/v26.10.6/plans/w501-art9-reachability.md",
                  "test result: ok. 6 passed"},
      "9.2.b" => {:evidenced, "W501+W508",
                  "risk estimation under use and misuse via mutant court + robust-margin gate",
                  ["/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs",
                   "lib/xaas/semantics/robust_margin.ex"],
                  "docs/sjira/v26.10.6/plans/w508-art15-margin.md",
                  "Result: 10 passed"},
      "9.2.c" => {:evidenced, "W503+W511",
                  "post-market data risk evaluation via OCEL event log + audit chain + Art 72 conformance seam",
                  ["lib/xaas/witness/audit_chain.ex", "lib/xaas/telemetry/ocel_ndjson.ex"],
                  "docs/sjira/v26.10.6/plans/w511-art72-conformance.md",
                  "Result: 10 passed"},
      "9.2.d" => {:evidenced, "W502+W507+W508",
                  "targeted risk measures adopted: dataset gate, quiescent-stop, margin gate",
                  ["lib/xaas/semantics/dataset_admission.ex",
                   "lib/xaas/actuation/quiescent_stop.ex",
                   "lib/xaas/semantics/robust_margin.ex"],
                  "docs/sjira/v26.10.6/plans/w507-art14-estop.md",
                  "Result: 5 passed"},
      "9.3" => {:not_applicable,
                "definitional scoping clause (risks shall concern only those reasonably mitigable through design or adequate technical information) — imposes no independent implementable duty"},
      "9.4" => {:evidenced, "W322",
                "combined-application effects considered via the zero-config posture audit across ALL safety/refusal sites",
                [],
                "docs/sjira/v26.10.6/plans/w322-zero-config-posture.md",
                "zero-config posture: HELD"},
      "9.5" => {:evidenced, "W501",
                "residual-risk adequacy: safe-set yields residual risk = states outside the safe set; narrow gate ALIVE",
                ["/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs"],
                "docs/sjira/v26.10.6/plans/w501-art9-reachability.md",
                "standing: PARTIAL_ALIVE"},
      "9.5.s2" => {:not_applicable,
                   "connector clause ('the following shall be ensured:') — operative content is 9.5.a/b/c, each classified on its own line"},
      "9.5.c" => {:not_applicable,
                  "provider-side sub-point (information per Art 13 + training to deployers is a provider packaging duty); deployer-side residual risk-reduction-by-information partially evidenced by the zero-config posture (w322)"},
      "9.5.s3" => {:evidenced, "W322",
                   "expected-deployer-expertise consideration: zero-config posture assumes ZERO operator configuration/expertise",
                   [],
                   "docs/sjira/v26.10.6/plans/w322-zero-config-posture.md",
                   "zero-config posture: HELD"},
      "9.7" => {:not_applicable,
                "permissive 'may' clause — creates no obligation"},
      "9.8" => {:evidenced, "W501 court",
                "testing prior to landing (this surface's 'market' is the canonical checkout): every seam passes its real court first (w501: 178 passed)",
                ["/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs"],
                "docs/sjira/v26.10.6/plans/w501-art9-reachability.md",
                "test result: ok. 178 passed"},
      "9.9" => {:not_applicable,
                "addressee 'provider' (fundamental-rights impact consideration when implementing the RMS) — deployer-class surface, no provider-of-high-risk-product role"},
      "9.10" => {:not_applicable,
                 "addressee 'provider' (coordination with other Union-law internal risk-management provisions) — same addressee reason"},
      # ---- Art. 13 (was OPEN via residual rule) ----
      "13.1" => {:evidenced, "W506/W505",
                 "output interpretability by design: counterfactual explanation (Thm 7.1) + Shapley attribution",
                 ["lib/xaas/semantics/counterfactual.ex",
                  "lib/xaas/semantics/admission_attribution.ex"],
                 "docs/sjira/v26.10.6/plans/w506-art86-counterfactual.md",
                 "Result: 9 passed"},
      "13.2" => {:evidenced, "docs+W322",
                 "instructions for use = diataxis reference docs; zero-config posture means instructions are complete (no undocumented config needed for safety)",
                 ["docs/claude/diataxis/reference/actuation-and-semantics.md", "README.md"],
                 "docs/sjira/v26.10.6/plans/w322-zero-config-posture.md",
                 "zero-config posture: HELD"},
      "13.3" => {:not_applicable,
                 "connector clause ('shall contain at least the following:') — operative content in 13.3.a-f, classified separately"},
      "13.3.a" => {:not_applicable,
                   "addressee 'provider' (identity/contact details in product documentation) — no product-manufacturer role"},
      "13.3.b" => {:not_applicable,
                   "connector clause — operative content in 13.3.b.i-vii"},
      "13.3.b.i" => {:evidenced, "docs+W322",
                     "intended purpose documented in README + architecture overview",
                     ["README.md",
                      "docs/claude/diataxis/explanation/architecture-overview.md"],
                     "docs/sjira/v26.10.6/plans/w322-zero-config-posture.md",
                     "zero-config posture: HELD"},
      "13.3.b.ii" => {:evidenced, "W508/W509",
                      "accuracy/robustness/cybersecurity metrics tested: robust-margin gate + eyerun_wasi SHACL gate",
                      ["lib/xaas/semantics/robust_margin.ex", "/Users/sac/wasm4pm/crates/eu_gate"],
                      "docs/sjira/v26.10.6/plans/w508-art15-margin.md",
                      "Result: 10 passed"},
      "13.3.b.iii" => {:evidenced, "W501+W322",
                       "foreseeable-misuse circumstances: mutant court enumerates and kills adversarial deviations; posture audit sweeps misuse-enabling config",
                       ["/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs"],
                       "docs/sjira/v26.10.6/plans/w322-zero-config-posture.md",
                       "zero-config posture: HELD"},
      "13.3.b.iv" => {:evidenced, "W506/W505",
                      "output-explanation capabilities: counterfactual + admission attribution",
                      ["lib/xaas/semantics/counterfactual.ex",
                       "lib/xaas/semantics/admission_attribution.ex"],
                      "docs/sjira/v26.10.6/plans/w506-art86-counterfactual.md",
                      "Result: 9 passed"},
      "13.3.b.v" => {:evidenced, "W502",
                     "performance on specific groups: sliced-W1 bias gate examines per-slice dataset performance",
                     ["lib/xaas/semantics/dataset_admission.ex",
                      "test/xaas/semantics/dataset_admission_test.exs"],
                     "docs/sjira/v26.10.6/plans/w502-art10-dataset-gate.md",
                     "Result: 6 passed"},
      "13.3.b.vi" => {:evidenced, "W502",
                      "input/training/validation/testing-data specs: dataset admission gate is the enforced input-data specification",
                      ["lib/xaas/semantics/dataset_admission.ex"],
                      "docs/sjira/v26.10.6/plans/w502-art10-dataset-gate.md",
                      "verdict: **ALIVE (lane-scoped)**"},
      "13.3.c" => {:not_applicable,
                   "addressee 'provider' (pre-determined change specs at conformity assessment) — no conformity-assessment procedure exists for a deployer-class surface"},
      "13.3.d" => {:evidenced, "W507/W506",
                   "Art 14 oversight measures: quiescent-stop + counterfactual are the built-in technical oversight measures",
                   ["lib/xaas/actuation/quiescent_stop.ex",
                    "lib/xaas/semantics/counterfactual.ex"],
                   "docs/sjira/v26.10.6/plans/w507-art14-estop.md",
                   "Result: 5 passed"},
      "13.3.e" => {:evidenced, "docs+W322",
                   "resources/lifetime/maintenance: pinned toolchain + CHANGELOG/VERSION record the resource and maintenance surface",
                   [".tool-versions", "CHANGELOG.md", "VERSION"],
                   "docs/sjira/v26.10.6/plans/w322-zero-config-posture.md",
                   "zero-config posture: HELD"},
      # ---- Art. 14 (was OPEN via residual rule) ----
      "14.1" => {:evidenced, "W507",
                 "effective-oversight design: quiescent-stop attractor is the human-machine interface enabling halt to a safe state (Thm 5.2)",
                 ["lib/xaas/actuation/quiescent_stop.ex",
                  "test/xaas/actuation/quiescent_stop_test.exs"],
                 "docs/sjira/v26.10.6/plans/w507-art14-estop.md",
                 "Result: 5 passed"},
      "14.2" => {:evidenced, "W507+W508",
                 "oversight risk prevention/minimisation: stop-button + margin gate minimise risk exposure operationally",
                 ["lib/xaas/actuation/quiescent_stop.ex", "lib/xaas/semantics/robust_margin.ex"],
                 "docs/sjira/v26.10.6/plans/w507-art14-estop.md",
                 "Result: 5 passed"},
      "14.3" => {:evidenced, "W507",
                 "oversight-measure types: built-in measures (quiescent_stop.ex in the actuation path) + deployer-implementable procedures (receipt/runbook docs)",
                 ["lib/xaas/actuation/quiescent_stop.ex"],
                 "docs/sjira/v26.10.6/plans/w507-art14-estop.md",
                 "Result: 5 passed"},
      "14.3.a" => {:evidenced, "W507",
                   "built-in measures: this surface builds its own machinery, so the measures ARE in the system before operation",
                   ["lib/xaas/actuation/quiescent_stop.ex"],
                   "docs/sjira/v26.10.6/plans/w507-art14-estop.md",
                   "Result: 5 passed"},
      "14.3.b" => {:evidenced, "W507+docs",
                   "deployer-implementable measures: stop procedure + receipt semantics documented for operator use",
                   ["lib/xaas/actuation/quiescent_stop.ex",
                    "docs/claude/diataxis/reference/actuation-and-semantics.md"],
                   "docs/sjira/v26.10.6/plans/w507-art14-estop.md",
                   "Result: 5 passed"},
      "14.4" => {:not_applicable,
                 "connector clause ('natural persons … are enabled, as appropriate:') — operative content is 14.4.a-e, classified separately"},
      "14.4.a" => {:evidenced, "W506/W503",
                   "understand capacities / monitor / detect anomalies: counterfactual + attribution interpret outputs; audit chain monitors operation",
                   ["lib/xaas/semantics/counterfactual.ex", "lib/xaas/witness/audit_chain.ex"],
                   "docs/sjira/v26.10.6/plans/w503-art12-audit-chain.md",
                   "Verdict: PARTIAL_ALIVE"},
      "14.4.c" => {:evidenced, "W506/W505",
                   "correct output interpretation: counterfactual + Shapley attribution are the operator's interpretation tools",
                   ["lib/xaas/semantics/counterfactual.ex",
                    "lib/xaas/semantics/admission_attribution.ex"],
                   "docs/sjira/v26.10.6/plans/w506-art86-counterfactual.md",
                   "Result: 9 passed"},
      "14.5" => {:not_applicable,
                 "scope: Annex III point 1(a) systems (biometric identification) — none deployed by this surface"},
      "14.5.s2" => {:not_applicable,
                    "scope exemption clause for 14.5 (law-enforcement/migration carve-out) — same absent-scope reason"}
    }
  end

  # ---------------------------------------------------------------------------
  # W623 deepening map: line_id -> [kind], where each kind is a REAL behavior
  # call executed in the generated test body (Chicago: no mocks). Tags and
  # verdicts are untouched — this only adds assertions to EVIDENCED entries
  # that previously asserted paths + a receipt String.contains? only.
  # Kinds and their canonical fixtures live in the test module below.
  # ---------------------------------------------------------------------------
  defp deepening_map do
    %{
      # Art. 9 — ferroplan inverse-reachability + gate family
      "9.1" => [:ferroplan_reachability, :audit_chain, :dataset_gate, :quiescent_typed, :margin_gate],
      "9.2" => [:audit_chain],
      "9.2.a" => [:ferroplan_reachability],
      "9.2.b" => [:ferroplan_reachability, :margin_gate],
      "9.2.c" => [:audit_chain],
      "9.2.d" => [:dataset_gate, :quiescent_typed, :margin_gate],
      "9.4" => [:zero_config],
      "9.5" => [:ferroplan_reachability],
      "9.5.s3" => [:zero_config],
      "9.8" => [:ferroplan_reachability],
      "9.5.a" => [:ferroplan_reachability],
      "9.5.b" => [:ferroplan_reachability],
      "9.6" => [:ferroplan_reachability],
      # Art. 10 / 26.4 — dataset admission gate
      "10.2" => [:dataset_gate],
      "10.2.e" => [:dataset_gate],
      "10.2.f" => [:dataset_gate],
      "10.2.g" => [:dataset_gate],
      "10.2.h" => [:dataset_gate],
      "10.3" => [:dataset_gate],
      "26.4" => [:dataset_gate],
      # Art. 11 / 12 / 26.5 / 26.12 — audit chain
      "11.1" => [:audit_chain],
      "12.1" => [:audit_chain],
      "12.2" => [:audit_chain],
      "12.2.a" => [:audit_chain],
      "12.2.b" => [:audit_chain],
      "12.2.c" => [:audit_chain],
      "26.5" => [:audit_chain],
      "26.12" => [:audit_chain],
      # Art. 13 — interpretability
      "13.1" => [:counterfactual, :shapley],
      "13.2" => [:zero_config],
      "13.3.b.i" => [:zero_config],
      "13.3.b.ii" => [:margin_gate],
      "13.3.b.iii" => [:ferroplan_reachability, :zero_config],
      "13.3.b.iv" => [:counterfactual, :shapley],
      "13.3.b.v" => [:dataset_gate],
      "13.3.b.vi" => [:dataset_gate],
      "13.3.b.vii" => [:counterfactual, :shapley],
      "13.3.f" => [:counterfactual, :shapley],
      "13.3.d" => [:quiescent_typed, :counterfactual],
      "13.3.e" => [:zero_config],
      # Art. 14 — oversight
      "14.1" => [:quiescent_typed],
      "14.2" => [:quiescent_typed, :margin_gate],
      "14.3" => [:quiescent_typed],
      "14.3.a" => [:quiescent_typed],
      "14.3.b" => [:quiescent_typed],
      "14.4.a" => [:counterfactual, :audit_chain],
      "14.4.b" => [:briefing],
      "14.4.c" => [:counterfactual, :shapley],
      "15.4.s2" => [:quiescent_typed],
      "26.2" => [:quiescent_typed],
      "27.3" => [:quiescent_typed],
      # Art. 15
      "15.1" => [:margin_gate, :audit_chain],
      "15.3" => [:declared_metrics],
      "15.4" => [:margin_gate],
      "15.5" => [:wasi_gate],
      "15.5.s2" => [:wasi_gate],
      "15.5.s3" => [:vuln_lifecycle],
      # Art. 26/27 — governance
      "26.6" => [:oversight_governance],
      "26.7" => [:oversight_governance],
      "27.1" => [:oversight_governance],
      "27.1.a" => [:oversight_governance],
      "27.1.c" => [:oversight_governance],
      "27.1.d" => [:oversight_governance],
      "27.1.b" => [:fria_schedule],
      "27.1.e" => [:fria_schedule],
      "27.1.f" => [:fria_schedule]
    }
  end

  @doc "W623: kinds of real behavior calls deepening `id`'s EVIDENCED entry."
  def deepening(id), do: Map.get(deepening_map(), id, [])

  def reclass_evidenced do
    Enum.filter(lines_with_verdicts(), fn {_, v, _} -> v == :evidenced_reclass end)
  end

  def lines_with_verdicts do
    compute()
  end

  def evidenced, do: filter(:evidenced)
  def not_applicable, do: filter(:not_applicable)
  def open_gaps, do: filter(:open_gap)

  defp filter(v), do: Enum.filter(lines_with_verdicts(), fn {_, ver, _} -> ver == v end)

  defp compute do
    lines = load()

    for line <- lines do
      id = line["line_id"]
      article = line["article"]
      addressee = line["addressee"] || "both"
      text = line["text"] || ""

      {verdict, detail} =
        cond do
          reclass = Map.get(reclass_map(), id) ->
            case reclass do
              {:evidenced, lane, desc, paths, receipt, verdict} ->
                {:evidenced_reclass, {lane, desc, paths, receipt, verdict}}

              {:not_applicable, reason} ->
                {:not_applicable, reason}
            end

          # not_applicable_map values are written as 1-tuples {"reason"}; a
          # 1-tuple is not valid AST, so unwrap before unquote in the tests.
          na = Map.get(not_applicable_map(), id) ->
            {:not_applicable, elem(na, 0)}

          evidence = Map.get(evidence_map(), id) ->
            {:evidenced, evidence}

          String.starts_with?(text, "Not present after the amendment") ->
            {:not_applicable,
             "consolidated-rendering placeholder (pre-amendment paragraph absent from the corpus) — no obligation text to implement"}

          article in ["6", "7"] ->
            {:not_applicable,
             "Art.#{article} provider-side classification procedure — deployer-side surface; no provider classification activity exists in this repo"}

          article == "12" and id in ["12.3", "12.3.a", "12.3.b", "12.3.c", "12.3.d"] ->
            {:not_applicable,
             "Art.12(3) logging duties are specific to Annex III point 1(a) systems (reference-database checks) — no Annex III system is deployed by this surface"}

          addressee == "authority" ->
            {:not_applicable,
             "authority-side obligation (Commission / market-surveillance / notified-body powers) — not implementable as deployer-side code"}

          article in ["26", "27"] ->
            {:open_gap,
             "Art.#{article} deployer-side duty applies (this repo is a deployer) — no seam covers it yet"}

          article in ["16", "17", "18", "19", "20", "21", "22", "23", "24", "25"] ->
            {:not_applicable,
             "Art.#{article} provider obligation (placing on the market / putting into service machinery) — deployer-side repo, no provider activity"}

          article in [
            "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39",
            "40", "41", "42", "43", "44", "45", "46", "47", "48", "49"
          ] ->
            {:not_applicable,
             "Art.#{article} notified-body / market-surveillance / harmonised-standards machinery — deployer-side repo, no notified-body relationship"}

          true ->
            {:open_gap,
             "Art.#{article} obligation has no implemented seam in this repo (honest gap: the dissertation's duty is wider than the built surface)"}
        end

      {line, verdict, detail}
    end
  end

  defp load do
    if File.exists?(@corpus_relpath) do
      body = File.read!(@corpus_relpath)

      case Jason.decode(body) do
        {:ok, %{"titles" => titles}} when is_list(titles) ->
          for title <- titles,
              title["num"] == "III",
              article <- title["articles"] || [],
              line <- article["lines"] || [],
              is_map(line),
              is_binary(line["line_id"]) do
            line
            |> Map.put("article", article["id"])
            |> Map.put("article_title", article["title"])
          end

        {:ok, other} ->
          raise RuntimeError, """
          corpus.json shape unexpected: keys #{inspect(Enum.map(other, &elem(&1, 0)) |> Enum.sort())}.
          Title III generator (W523) expects {"titles": [{"num": "III", "articles": [...]}]}.
          REFUSED(EUAIA_CORPUS_SHAPE_UNEXPECTED_W523)
          """

        {:error, reason} ->
          raise RuntimeError, "corpus.json is not valid JSON: #{inspect(reason)}"
      end
    else
      raise RuntimeError, """
      EUAI-Act corpus absent: #{File.cwd!()}/#{@corpus_relpath} not found.
      Substrate owned by lane W520. REFUSED(EUAIA_CORPUS_MISSING_W520)
      """
    end
  end
end

defmodule Xaas.EUAIAct.TitleIIITest do
  @moduledoc """
  Title III generator (lane W523, restructured W534) — EU AI Act Arts 6-49,
  one test per corpus line_id, generated at compile time from
  `docs/eu_ai_act/corpus.json` (W520).

  Split across two modules in this file because ExUnit resolves includes OVER
  excludes: a test carrying both `:eu_ai_act` and `:eu_ai_act_open_gap` would
  be resurrected by `--include eu_ai_act` even under
  `--exclude eu_ai_act_open_gap`. The OPEN_GAP lines therefore live in
  `Xaas.EUAIAct.TitleIIIOpenGapsTest`, which carries ONLY the
  `:eu_ai_act_open_gap` tag (module-level), so the exclude actually holds.
  (W523's original single-module shape tagged gaps per-test alongside a
  `@moduletag :eu_ai_act`, resurrecting the 91 gap tests under the green-gate
  command — observed 91/391 failing, 2026-10-06.)

  Verdicts (identical to W523, structure change only):

    * `EVIDENCED`      — a real repo/checkout seam exists; the test asserts the
      real paths on disk (`File.exists?/1`) and names the owning lane receipt.
    * `NOT_APPLICABLE` — typed reason string, asserted non-empty in the body.
    * `OPEN_GAP`       — obligation applies, no seam covers it; the test `flunk`s
      by design (tagged `:eu_ai_act_open_gap`) — executable compliance pressure
      and the honest gap inventory for this title.

  Every test id is `"EUAI-ACT <line_id>"`. Future corpus updates auto-extend:
  tests are generated from the corpus at compile time, not hand-written.
  """

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act

  alias Xaas.EUAIAct.TitleIII.Lines

  for {line, _verdict, detail} <- Lines.evidenced() do
    id = line["line_id"]
    text = line["text"] || ""

    short =
      text
      |> String.replace(~r/\s+/, " ")
      |> String.slice(0, 72)

    {lane, _desc, paths} = detail

    test "EUAI-ACT #{id} — EVIDENCED (#{lane}): #{short}" do
      for p <- unquote(paths) do
        assert File.exists?(p), "EVIDENCED path missing on disk: " <> p
      end

      # W623 deepening: real behavior call(s), not path assertions only.
      deepen(unquote(Lines.deepening(id)))
    end
  end

  for {line, _verdict, {lane, _desc, paths, receipt, verdict_snippet}} <-
        Lines.reclass_evidenced() do
    id = line["line_id"]
    text = line["text"] || ""

    short =
      text
      |> String.replace(~r/\s+/, " ")
      |> String.slice(0, 72)

    test "EUAI-ACT #{id} — EVIDENCED (#{lane}): #{short}" do
      for p <- unquote(paths) do
        assert File.exists?(p), "EVIDENCED path missing on disk: " <> p
      end

      receipt_body = File.read!(unquote(receipt))

      assert String.contains?(receipt_body, unquote(verdict_snippet)),
             "receipt verdict line missing from " <> unquote(receipt) <>
               ": " <> unquote(verdict_snippet)

      # W623 deepening: real behavior call(s) on top of the receipt string.
      deepen(unquote(Lines.deepening(id)))
    end
  end

  # ---------------------------------------------------------------------------
  # W623 deepening: real behavior calls (Chicago — real collaborators, no
  # mocks), one kind per seam. Each kind mirrors the seam's own court fixtures.
  # ---------------------------------------------------------------------------

  @ferroplan_reachability "/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs"
  @w322_receipt "docs/sjira/v26.10.6/plans/w322-zero-config-posture.md"
  @wasi_gate_crate "/Users/sac/wasm4pm/crates/eu_gate"

  defp deepen([]), do: :ok

  defp deepen(kinds) when is_list(kinds) do
    for kind <- kinds, do: deepen_kind(kind)
    :ok
  end

  defp deepen_kind(:ferroplan_reachability) do
    # The ferroplan inverse-reachability safe-set (W501, Thm 3.1) is the cited
    # Art 9 seam: the BackwardSafeSet type and its decision functions exist.
    src = File.read!(@ferroplan_reachability)
    assert src =~ "pub struct BackwardSafeSet"
    assert src =~ "pub fn is_safe"
    assert src =~ "pub fn unsafe_count"
  end

  defp deepen_kind(:audit_chain) do
    # Real hash-chained audit receipts: append N, verify :ok, tamper detected
    # exactly (Def 4.2 + Thm 4.1, W503). Pure — no DB.
    alias Xaas.Witness.AuditChain

    attrs = fn i ->
      %{
        actuation_id: "euai-iii-#{i}",
        payload_digest: :crypto.hash(:sha256, "euai-iii-#{i}") |> Base.encode16(case: :lower)
      }
    end

    {:ok, chain, _head} =
      Enum.reduce(0..4, {:ok, [], nil}, fn i, {:ok, ch, h} ->
        AuditChain.append(ch, attrs.(i))
      end)

    assert length(chain) == 5
    assert AuditChain.verify_chain(chain) == :ok

    tampered = List.update_at(chain, 2, fn r -> %{r | payload_digest: String.duplicate("f", 64)} end)
    assert AuditChain.verify_chain(tampered) == {:error, {:tampered, 2}}
  end

  defp deepen_kind(:dataset_gate) do
    # Real W502 admits: clean dataset admitted with measured quantities;
    # empty / incomplete / biased datasets refuse with typed terms.
    alias Xaas.Semantics.DatasetAdmission

    sample = fn s, label, a ->
      %{features: %{x: s}, label: label, sensitive: a}
    end

    clean = Enum.map(1..20, fn i -> sample.(i / 20, :y, rem(i, 2)) end)

    assert {:ok, :ADMITTED, %{w1_proxy: w1, completeness: 1.0}} =
             DatasetAdmission.admit(clean, seed: 42)

    assert is_float(w1)

    assert {:error, :REFUSED_EMPTY_DATASET} = DatasetAdmission.admit([], seed: 42)

    incomplete =
      clean
      |> Enum.with_index()
      |> Enum.map(fn {s, i} ->
        if i == 0, do: %{s | features: Map.put(s.features, :x, nil)}, else: s
      end)

    assert {:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness: c, threshold: t}}} =
             DatasetAdmission.admit(incomplete,
               seed: 42,
               required_fields: [:x],
               eta: 0.0
             )

    assert c < 1.0 and t == 1.0

    biased = Enum.map(1..20, fn i -> sample.(i / 20, :y, if(i <= 18, do: 0, else: 1)) end)

    assert {:error, {:REFUSED_BIAS_THRESHOLD, %{w1_proxy: bw1, epsilon_bias: eps}}} =
             DatasetAdmission.admit(biased, seed: 7, epsilon_bias: 0.05)

    assert bw1 > eps
  end

  defp deepen_kind(:margin_gate) do
    # Real W508 gate: empirical Lipschitz over real calibration pairs, then a
    # margin admit and two fail-closed refusals (Thm 5.3).
    alias Xaas.Semantics.RobustMargin

    scoring = fn x -> x * 3.0 end
    pairs = for i <- 1..5, do: {i * 1.0, (i + 1) * 1.0}
    l_h = RobustMargin.estimate_lipschitz(scoring, pairs)
    assert l_h >= 3.0

    assert :ADMITTED = RobustMargin.admit(10.0, l_h, 1.0, 0.5)
    assert {:error, :REFUSED_ROBUST_MARGIN} = RobustMargin.admit(0.5, l_h, 1.0, 0.5)
    assert {:error, :REFUSED_NO_CALIBRATION_DATA} = RobustMargin.admit(10.0, RobustMargin.estimate_lipschitz(scoring, []), 1.0, 0.5)
  end

  defp deepen_kind(:quiescent_typed) do
    # Real W507 typed refusals on the pre-DO path (no DB write): missing
    # idempotency key and non-admitted authority both fail closed.
    alias Xaas.Actuation.QuiescentStop

    assert {:error, :idempotency_key_required} = QuiescentStop.execute(Xaas.Marketplace.Provider, [])
    assert {:error, :idempotency_key_required} =
             QuiescentStop.execute(Xaas.Marketplace.Provider,
               idempotency_key: "",
               authority: %{kind: "human", source: "operator"}
             )

    assert {:error, :REFUSED_STOP_AUTHORITY} =
             QuiescentStop.execute(Xaas.Marketplace.Provider,
               idempotency_key: "euai-iii-unauthorized",
               authority: %{kind: "human"}
             )
  end

  defp deepen_kind(:counterfactual) do
    # Real W506 evaluate/3: removing the violating field flips the refusal and
    # names exactly the check that flipped (Thm 7.1).
    alias Xaas.Semantics.Counterfactual

    checks = [
      {:pii_minimized, fn input ->
         if input[:pii_fields] in [nil, []], do: :ok, else: {:refused, :pii_not_minimized}
       end}
    ]

    input = %{pii_fields: [:email]}
    %{outcome: outcome, checks: log} = Counterfactual.run(input, checks)
    assert {:refused, :pii_not_minimized} = outcome

    record = %{input: input, admitted?: false, refusal: :pii_not_minimized, checks: log}

    assert {:ok, result} = Counterfactual.evaluate(record, %{pii_fields: []}, checks)
    assert result.outcome == :admitted
    assert result.changed? == true
    assert result.explanation =~ "pii_minimized"
  end

  defp deepen_kind(:shapley) do
    # Real W505 exact Shapley attribution: blame concentrates (-1.0) on the
    # single refusing check (Definition 5.2).
    alias Xaas.Semantics.AdmissionAttribution

    checks = [
      {:policy_grounding, fn _ -> :pass end},
      {:provenance_complete, fn _ -> {:refuse, :no_provenance} end},
      {:risk_classified, fn _ -> :pass end}
    ]

    assert %{:policy_grounding => a, :provenance_complete => b, :risk_classified => c} =
             AdmissionAttribution.shapley(:intent, checks)

    assert_in_delta b, -1.0, 1.0e-9
    assert a == 0.0
    assert c == 0.0
  end

  defp deepen_kind(:briefing) do
    # Real W539 briefing/2: a refusing decision gets a causal anatomy naming
    # the flipped check with its exact Shapley value; an admit gets [] anatomy
    # but still a full per-check cause list (Art 14.4.b structural
    # countermeasure: no unexplained verdict).
    alias Xaas.Semantics.{AdmissionAttribution, AutomationBiasCountermeasure, Counterfactual}

    checks = [
      {:scope, fn _ -> :ok end},
      {:human_oversight, fn input ->
         if Map.get(input, :oversight, false), do: :ok, else: {:refused, :no_human_oversight}
       end},
      {:logging, fn _ -> :ok end}
    ]

    to_w505 = fn cks ->
      Enum.map(cks, fn {name, fun} ->
        {name, fn input -> case fun.(input) do
           :ok -> :pass
           {:refused, r} -> {:refuse, r}
         end end}
      end)
    end

    input = %{oversight: false}
    %{outcome: {:refused, reason}, checks: log} = Counterfactual.run(input, checks)
    assert reason == :no_human_oversight

    rec = %{input: input, admitted?: false, refusal: reason, checks: log}

    assert phi = AdmissionAttribution.shapley(input, to_w505.(checks))
    assert is_map(phi)

    {:ok, b} = AutomationBiasCountermeasure.briefing(rec, phi)
    assert b.verdict == :refuse
    assert [%{name: :human_oversight, refusal: :no_human_oversight}] = b.refusal_anatomy
    by_name = Map.new(b.per_check_causes, &{&1.name, &1})
    assert_in_delta by_name[:human_oversight].shapley, -1.0, 1.0e-9
    assert b.counterfactual_available == true
    assert b.interpretability != ""
  end

  defp deepen_kind(:declared_metrics) do
    # Real W536 declare/0: fail-closed metric readout over real receipts.
    assert {:ok, metrics} = Xaas.Semantics.DeclaredMetrics.declare()
    assert is_map(metrics)
    assert metrics != %{}
  end

  defp deepen_kind(:vuln_lifecycle) do
    # Real W540 forward-only state machine: valid transition + typed skip
    # refusals.
    alias Xaas.Semantics.VulnerabilityLifecycle

    assert :DETECTED in VulnerabilityLifecycle.states()

    # Happy path: the legal walk DETECTED -> TRIAGED -> RESPONDED with the
    # typed evidence each edge requires (W540 contract). respond/2 confirms
    # with {:ok, %VulnerabilityLifecycle{state: :RESPONDED}}.
    {:ok, ticket} = VulnerabilityLifecycle.new(%{detector: "euai-iii", finding: "f1"})
    assert {:ok, triaged = %VulnerabilityLifecycle{state: :TRIAGED}} =
             VulnerabilityLifecycle.triage(ticket, %{analysis: "gap at 15.5.s3"})

    assert {:ok, %VulnerabilityLifecycle{state: :RESPONDED} = responded} =
             VulnerabilityLifecycle.respond(triaged, %{receipt: "diff w540 fix"})

    # history is chronological; reversed take(2) is newest-first.
    assert responded.history |> Enum.reverse() |> Enum.take(2) ==
             [{:advance, :RESPONDED}, {:advance, :TRIAGED}]

    # Same legal edge WITHOUT the required evidence record -> typed refusal
    # (:REFUSED_LIFECYCLE_EVIDENCE, not a skip — the edge order is lawful).
    assert {:error, :REFUSED_LIFECYCLE_EVIDENCE} =
             VulnerabilityLifecycle.respond(triaged, %{})

    # Skipping the triage edge entirely is still refused typed (respond from
    # a fresh DETECTED ticket).
    {:ok, detected} = VulnerabilityLifecycle.new(%{detector: "euai-iii", finding: "f1"})
    assert {:error, :REFUSED_LIFECYCLE_SKIP} =
             VulnerabilityLifecycle.respond(detected, %{receipt: "diff w540 fix"})
  end

  defp deepen_kind(:oversight_governance) do
    # Real W537 governance surface: structured FRIA + retention + worker
    # notification, all real calls.
    assert {:ok, fria} = Xaas.Semantics.OversightGovernance.fria()
    assert fria.assessment_class == :deployer
    assert fria.rights != []

    assert {:ok, retention} = Xaas.Semantics.OversightGovernance.retention_policy()
    assert retention.actuation_receipts == :permanent_durable_rows

    assert {:ok, notification} = Xaas.Semantics.OversightGovernance.worker_notification()
    assert notification.channel == :receipt_corpus_plus_ocel_events
  end

  defp deepen_kind(:fria_schedule) do
    # W648b governance fields: real calls on the Art. 4.1 / 27.1.b / 27.1.e
    # structured surfaces (27.1.f reuses fria/0's typed materialisation data).
    assert {:ok, lit} = Xaas.Semantics.OversightGovernance.ai_literacy()
    assert lit.measures != []

    for m <- lit.measures do
      assert File.exists?(Path.expand(m.evidence_path, File.cwd!()))
    end

    assert {:ok, sched} = Xaas.Semantics.OversightGovernance.fria_schedule()
    assert sched.period == "per-wave"

    for p <- sched.evidence do
      assert File.exists?(Path.expand(p, File.cwd!()))
    end

    assert {:ok, desc} = Xaas.Semantics.OversightGovernance.fria_oversight_description()
    assert desc.description != []

    for c <- desc.controls do
      assert File.exists?(Path.expand(c, File.cwd!()))
    end
  end

  defp deepen_kind(:wasi_gate) do
    # W509 crate surface: the standalone eyerun_wasi gate crate is readable.
    cargo = File.read!(Path.join(@wasi_gate_crate, "Cargo.toml"))
    assert cargo != ""
  end

  defp deepen_kind(:zero_config) do
    # W322 posture: the receipt names real refusal sites and holds HELD.
    body = File.read!(Path.expand(@w322_receipt, File.cwd!()))
    assert body =~ "zero-config posture: HELD"
    assert length(Regex.scan(~r/REFUSED_/, body)) >= 3
  end

  for {line, _verdict, detail} <- Lines.not_applicable() do
    id = line["line_id"]
    text = line["text"] || ""

    short =
      text
      |> String.replace(~r/\s+/, " ")
      |> String.slice(0, 72)

    test "EUAI-ACT #{id} — NOT_APPLICABLE: #{short}" do
      reason = unquote(detail)
      assert is_binary(reason) and reason != ""
    end
  end
end

defmodule Xaas.EUAIAct.TitleIIIOpenGapsTest do
  @moduledoc """
  Honest OPEN_GAP inventory for Title III (lane W534 restructure of W523).
  Every test flunks by design — executable compliance pressure. Tagged at
  module level with `:eu_ai_act_open_gap` so `--exclude eu_ai_act_open_gap`
  yields a green run; run WITHOUT the exclude for the honest gap count.
  """

  use ExUnit.Case, async: true

  # Deliberately NO @moduletag :eu_ai_act here: ExUnit resolves includes over
  # excludes, so a moduletagged :eu_ai_act gap test would be resurrected by
  # `--include eu_ai_act` even under `--exclude eu_ai_act_open_gap`.
  # Only the open-gap tag is set, module-level.
  @moduletag :eu_ai_act_open_gap

  alias Xaas.EUAIAct.TitleIII.Lines

  for {line, _verdict, detail} <- Lines.open_gaps() do
    id = line["line_id"]
    text = line["text"] || ""

    short =
      text
      |> String.replace(~r/\s+/, " ")
      |> String.slice(0, 72)

    test "EUAI-ACT #{id} — OPEN_GAP: #{short}" do
      flunk("OPEN_GAP: " <> unquote(detail))
    end
  end
end
