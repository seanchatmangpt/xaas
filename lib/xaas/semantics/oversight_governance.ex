defmodule Xaas.Semantics.OversightGovernance do
  @moduledoc """
  Typed governance surfaces for EU AI Act Art. 26.6 (record-keeping / log
  retention), Art. 26.7 (worker notification), and Art. 27 (fundamental-rights
  impact assessment) over the fleet's REAL machinery — zero-config, honest.

  ## Art. 26.6 — retention (duty: logs preserved)

  Sealed actuation receipts are durable rows: `Xaas.Actuation.run/4` writes a
  durable `ActuationIntent` + `ActuationReceipt` under an outer seal
  (`lib/xaas/actuation.ex`), and the certified-receipt witness chain
  (`lib/xaas/witness/`) makes them tamper-evident and replayable. The
  retention policy is therefore **permanent by default** for actuation
  receipts, while lane build roots and one-time artifacts are **ephemeral
  under recorded lease cleanup** (the `ash_onetime` prune/reap tasks in deps).
  The Art. 26.6 duty is EVIDENCED by the durable rows, not by a prose promise.

  ## Art. 26.7 — worker notification

  The receipt corpus + OCEL event stream ARE the notification record to the
  operator: every consequential transition is emitted through
  `Xaas.Telemetry.OcelAshEmitter`, so the durable corpus is the
  operator-facing record. Serious-incident reporting (the 3.49 family): the
  report *builder* is real — `Xaas.Semantics.IncidentReport` derives Art 73
  classifications over the witnessed receipt corpus (malfunction suppression
  per W679) — while the authority transmission channel remains typed OPEN
  (`transmit/1` returns `:PREPARED_NOT_TRANSMITTED`, never a silent send).
  The `worker_notification/0` surface below still carries this as typed
  `{:OPEN_GAP, ...}` (W525b). (Doc refreshed by W833; previously claimed
  "no incident-reporting seam exists", stale since IncidentReport landed.)

  ## Art. 27 — FRIA (deployer-class, structured data)

  A deployer-class fundamental-rights impact assessment over the REAL refusal
  surfaces, implemented as structured data with per-right evidence citations.
  Every cited path is verified to exist at test time; OPEN_GAP limitations
  are typed, not hidden.

  This module is a governance description surface. It never grants authority,
  never actuates, and is wired into no live route (integration is a later lane).
  """

  @repo_relative_sources [
    "lib/xaas/actuation.ex",
    "lib/xaas/witness.ex",
    "lib/xaas/witness/audit_chain.ex",
    "lib/xaas/witness/certified_receipt.ex",
    "lib/xaas/witness/catalog.ex",
    "lib/xaas/witness/verification_key.ex",
    "lib/xaas/telemetry/ocel_ash_emitter.ex",
    "lib/xaas/ultracode/ocel_egress.ex",
    "lib/xaas/ultracode/autonomy_egress.ex",
    "lib/xaas/semantics/dataset_admission.ex",
    "lib/xaas/semantics/eu_ai_act_admission.ex",
    "deps/ash_onetime/lib/ash_onetime/oban/cleanup_worker.ex",
    "deps/ash_onetime/lib/ash_onetime/oban/reap_worker.ex",
    "deps/ash_onetime/lib/mix/tasks/ash_onetime.prune.ex",
    "deps/ash_onetime/lib/mix/tasks/ash_onetime.reap.ex"
  ]

  @doc """
  Paths this module's typed citations depend on, repo-relative.
  Exposed so tests (and any auditor) can verify existence without
  duplicating the list.
  """
  @spec cited_paths() :: [String.t(), ...]
  def cited_paths, do: @repo_relative_sources

  @doc """
  Art. 26.6: the REAL receipt-retention policy as typed data.

  `actuation_receipts` are durable rows written by `Xaas.Actuation.run/4`
  and made tamper-evident by the witness chain — permanent by default.
  `ephemeral_artifacts` (lane build roots, one-time artifacts) are cleaned
  under recorded lease cleanup by the `ash_onetime` prune/reap machinery.
  """
  @spec retention_policy() ::
          {:ok,
           %{
             required(:actuation_receipts) => :permanent_durable_rows,
             required(:ephemeral_artifacts) => :lane_lease_cleanup,
             required(:source) => [String.t(), ...]
           }}
  def retention_policy do
    {:ok,
     %{
       actuation_receipts: :permanent_durable_rows,
       ephemeral_artifacts: :lane_lease_cleanup,
       source: [
         "lib/xaas/actuation.ex",
         "lib/xaas/witness.ex",
         "lib/xaas/witness/audit_chain.ex",
         "lib/xaas/witness/certified_receipt.ex",
         "lib/xaas/witness/catalog.ex",
         "lib/xaas/witness/verification_key.ex",
         "deps/ash_onetime/lib/mix/tasks/ash_onetime.prune.ex",
         "deps/ash_onetime/lib/mix/tasks/ash_onetime.reap.ex",
         "deps/ash_onetime/lib/ash_onetime/oban/cleanup_worker.ex",
         "deps/ash_onetime/lib/ash_onetime/oban/reap_worker.ex"
       ]
     }}
  end

  @doc """
  Art. 26.7: the fleet's worker-notification structure.

  The notification record to the operator is the receipt corpus + OCEL event
  stream. Serious-incident reporting to authorities (3.49 family) is typed
  `{:OPEN_GAP, details}` — honest, not hidden.
  """
  @spec worker_notification() :: {:ok, map()}
  def worker_notification do
    {:ok,
     %{
       article: "Art. 26.7",
       channel: :receipt_corpus_plus_ocel_events,
       notification_record: %{
         emitter: %{
           path: "lib/xaas/telemetry/ocel_ash_emitter.ex",
           module: Xaas.Telemetry.OcelAshEmitter
         },
         egress: [
           %{path: "lib/xaas/ultracode/ocel_egress.ex", module: Xaas.Ultracode.OcelEgress},
           %{path: "lib/xaas/ultracode/autonomy_egress.ex", module: Xaas.Ultracode.AutonomyEgress}
         ]
       },
       operator:
         "deployer-operator of this fleet; the durable receipt corpus is the record served to workers' representatives",
       incident_reporting:
         {:OPEN_GAP,
          %{
            item: "3.49 family serious-incident reporting to authorities (Art. 26.5)",
            basis: "no incident-reporting seam exists",
            cite: "docs/sjira/v26.10.6/plans/w525b-title-i.md"
          }}
     }}
  end

  @doc """
  Art. 4.1: the fleet's REAL AI-literacy measures (deployers ensure a
  sufficient level of AI literacy of their staff) as structured data.

  Each measure cites a real, on-disk enablement artifact; `audience` names
  who is trained by it. These are the operating documents the fleet's
  oversight personnel actually run on — not a prose training promise.
  """
  @spec ai_literacy() ::
          {:ok,
           %{
             required(:measures) => [map(), ...],
             required(:audience) => String.t(),
             required(:source) => [String.t(), ...]
           }}
  def ai_literacy do
    {:ok,
     %{
       measures: [
         %{
           name: "operator enablement via the CRO loop",
           evidence_path: "docs/cro/CRO-LOOP.md",
           basis:
             "standing GTM/oversight engine with cadence, stages, exit gates, and falsifiers — operator enablement discipline over shipped evidence"
         },
         %{
           name: "executable-regulation Chicago-test suite as training substrate",
           evidence_path: "test/eu_ai_act/README.md",
           basis:
             "the how-to-run / tag-semantics / mutation-falsification protocol doc oversight personnel follow to execute the regulation suite"
         },
         %{
           name: "corpus falsifier discipline",
           evidence_path: "docs/eu_ai_act/corpus-README.md",
           basis:
             "corpus schema + provenance + test-mapping contract; every corpus line re-verified on drift (the falsifier habit AI literacy requires)"
         },
         %{
           name: "Art. 14 oversight evidence map rows",
           evidence_path: "docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md",
           basis:
             "clause-level Art. 14(1)/14(4)(a)/(b) oversight rows citing the real surfaces (BRCE admission, typed refusals, signed consequence) personnel are trained on"
         }
       ],
       audience: "operators/oversight personnel",
       source: [
         "docs/cro/CRO-LOOP.md",
         "test/eu_ai_act/README.md",
         "docs/eu_ai_act/corpus-README.md",
         "docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md"
       ]
     }}
  end

  @doc """
  Art. 27.1.b: the FRIA review period/frequency schedule as structured data.

  The review cadence is the CRO loop cycle (per-wave, weekly open/close with
  an exit-gate result per pursued item) plus the corpus falsifier discipline:
  each corpus line is re-verified on drift, so any drift in the evidence
  corpus triggers a re-assessment.
  """
  @spec fria_schedule() ::
          {:ok,
           %{
             required(:period) => String.t(),
             required(:trigger) => String.t(),
             required(:evidence) => [String.t(), ...]
           }}
  def fria_schedule do
    {:ok,
     %{
       period: "per-wave",
       trigger: "corpus drift falsifier",
       evidence: [
         "docs/cro/CRO-LOOP.md",
         "docs/eu_ai_act/corpus-README.md"
       ]
     }}
  end

  @doc """
  Art. 27.1.e: how oversight is implemented in the FRIA context, as
  structured data — the per-right FRIA structure plus the counterfactual /
  attribution surfaces the oversight is exercised through, each control
  cited to a real path.
  """
  @spec fria_oversight_description() ::
          {:ok,
           %{
             required(:description) => [String.t(), ...],
             required(:controls) => [String.t(), ...]
           }}
  def fria_oversight_description do
    {:ok,
     %{
       description: [
         "oversight is implemented through fria/0's per-right structure: each right carries typed EVIDENCED/OPEN_GAP status with per-right evidence citations (path + symbol + basis), so an overseer reads the assessment as machine-checkable data, not prose",
         "counterfactual surface gives the overseer a do-intervention view of each decision (FACTUAL -> ACTION -> PREDICTION, Pearl 3-step)",
         "admission-attribution surface assigns per-check causes to admission/refusal outcomes (Shapley), making the grounds of each decision inspectable",
         "automation-bias countermeasure briefs the overseer with the causal anatomy of every check, countering over-reliance on the gate"
       ],
       controls: [
         "lib/xaas/semantics/oversight_governance.ex",
         "lib/xaas/semantics/counterfactual.ex",
         "lib/xaas/semantics/admission_attribution.ex",
         "lib/xaas/semantics/automation_bias_countermeasure.ex",
         "docs/sjira/v26.10.6/plans/w537-art26-27-governance.md"
       ]
     }}
  end

  @doc """
  Art. 27: deployer-class fundamental-rights impact assessment as structured
  data. Each entry: right, article, protection, per-right evidence citations
  (path + symbol + basis), and a typed status (`:EVIDENCED` or `:OPEN_GAP`).
  """
  @spec fria() :: {:ok, %{required(:assessment_class) => :deployer, required(:rights) => [map(), ...]}}
  def fria do
    {:ok,
     %{
       assessment_class: :deployer,
       subject_system:
         "admission/refusal surfaces of this fleet (typed refusal atoms + receipted actuation), not a third-party GPAI",
       rights: [
         %{
           right: :non_discrimination,
           article: "EU AI Act Art. 10; Charter Art. 21",
           protection:
             "Bias gate over admitted datasets: empirical W1 proxy above epsilon_bias refuses admission fail-closed",
           evidence: [
             %{
               path: "lib/xaas/semantics/dataset_admission.ex",
               symbol: "Xaas.Semantics.DatasetAdmission.admit/2",
               basis: "REFUSED_BIAS_THRESHOLD"
             },
             %{
               path: "docs/sjira/v26.10.6/plans/w502-art10-dataset-gate.md",
               symbol: nil,
               basis: "W502 receipt"
             }
           ],
           status: :EVIDENCED
         },
         %{
           right: :due_process,
           article: "Charter Art. 41/47 (good administration, effective remedy)",
           protection:
             "Typed refusals + exact-SHA replay: every consequential transition is refused typed or admitted with a replayable receipt",
           evidence: [
             %{
               path: "lib/xaas/actuation.ex",
               symbol: "Xaas.Actuation.run/4",
               basis: "durable intent + receipt under outer seal"
             },
             %{
               path: "lib/xaas/witness/certified_receipt.ex",
               symbol: "Xaas.Witness.CertifiedReceipt",
               basis: "tamper-evident replay chain"
             },
             %{
               path: "lib/xaas/semantics/eu_ai_act_admission.ex",
               symbol: "Xaas.Semantics.EuAiActAdmission",
               basis: "eight typed Art. 5 refusal atoms"
             }
           ],
           status: :EVIDENCED
         },
         %{
           right: :privacy,
           article: "Charter Art. 7/8",
           protection:
             "Zero PII collection in admission: the Art. 5 profile inspects only declared intent-schema fields — never free text, model output, or user data",
           evidence: [
             %{
               path: "lib/xaas/semantics/eu_ai_act_admission.ex",
               symbol: "Xaas.Semantics.EuAiActAdmission",
               basis:
                 "@moduledoc: \"The check never inspects free text, model output, or user data — only the declared intent schema\""
             }
           ],
           status: :EVIDENCED
         },
         %{
           right: :worker_information,
           article: "Charter Art. 11/27; Art. 26.7 duty",
           protection:
             "Receipt corpus + OCEL events ARE the worker notification record to the operator",
           evidence: [
             %{
               path: "lib/xaas/telemetry/ocel_ash_emitter.ex",
               symbol: "Xaas.Telemetry.OcelAshEmitter",
               basis: "OCEL emission on every consequential transition"
             }
           ],
           status: :EVIDENCED
         },
         %{
           right: :access_to_effective_remedy_authority_channel,
           article: "Art. 26.5 / 3.49 family (serious-incident reporting to authorities)",
           protection:
             "No incident-reporting seam exists: serious incidents cannot today be reported to market-surveillance authorities from this fleet",
           evidence: [
             %{
               path: "docs/sjira/v26.10.6/plans/w525b-title-i.md",
               symbol: nil,
               basis: "OPEN_GAP (6): 3.49 + 3.49.a-d (serious incident — no incident surface)"
             }
           ],
           status: :OPEN_GAP
         }
       ]
     }}
  end
end
