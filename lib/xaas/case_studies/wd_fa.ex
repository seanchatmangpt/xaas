defmodule Xaas.CaseStudies.WdFa do
  @moduledoc """
  Deterministic WD Case Study 2 reference kernel.

  Toyota/TPS supplies the quality-loop structure only:
  standard -> observation -> abnormality -> work -> disposition ->
  verified experience -> improved standard.

  This module reuses the repository's existing Ash-backed OCEL 2.0 resources
  instead of inventing a parallel WD persistence model. Candidate ranking is
  not authority. Consequential FA disposition remains
  ENGINEER_DISPOSITION_REQUIRED.
  """

  alias Xaas.Ocel.{Event, Object, ObjectObject, Projection}

  @scenarios %{
    "known_firmware" => %{
      title: "Known firmware timeout",
      symptom: "intermittent command timeout",
      evidence: ["fw_trace", "timeout_waveform", "lot_genealogy"],
      required: ["fw_trace", "timeout_waveform"],
      candidate_mode: "MODE-A-FIRMWARE",
      next_action: "RUN_FIRMWARE_DIAGNOSTIC_T14",
      owning_team: "firmware_analysis",
      prior_cases: ["FA-2019-0042", "FA-2024-0117"]
    },
    "partial_firmware" => %{
      title: "Incomplete firmware timeout",
      symptom: "intermittent command timeout",
      evidence: ["fw_trace", "lot_genealogy"],
      required: ["fw_trace", "timeout_waveform"],
      candidate_mode: "MODE-A-FIRMWARE",
      next_action: "ACQUIRE_TIMEOUT_WAVEFORM",
      owning_team: "failure_analysis",
      prior_cases: ["FA-2019-0042", "FA-2024-0117"]
    },
    "novel_x" => %{
      title: "Novel cross-layer signature",
      symptom: "non-deterministic replay mismatch",
      evidence: ["servo_trace", "media_scan", "lot_genealogy"],
      required: [],
      candidate_mode: "MODE-X-CANDIDATE",
      next_action: "ESCALATE_NOVEL_INVESTIGATION",
      owning_team: "failure_analysis",
      prior_cases: []
    }
  }

  @object_types [
    "FailureCase",
    "Drive",
    "Lot",
    "Supplier",
    "BOMRevision",
    "FirmwareRevision",
    "TestStation",
    "EvidenceArtifact",
    "StandardWork"
  ]

  def scenario_ids, do: @scenarios |> Map.keys() |> Enum.sort()
  def object_types, do: @object_types

  def presentation_state(id, experience_admitted? \\ false) do
    scenario = Map.fetch!(@scenarios, id)
    missing = scenario.required -- scenario.evidence

    cond do
      id == "novel_x" and experience_admitted? ->
        build_state(scenario,
          classification: "KNOWN",
          standing: "ALIVE",
          confidence_basis: "ADMITTED_MACHINE_EXPERIENCE",
          missing_evidence: [],
          admitted_mode: "MODE-X-NOVEL",
          prior_cases: ["MX-NOVEL-X-001"],
          next_action: "RUN_NOVEL_X_STANDARD_WORK"
        )

      id == "novel_x" ->
        build_state(scenario,
          classification: "UNKNOWN",
          standing: "UNKNOWN",
          confidence_basis: "NO_ADMITTED_PRIOR_ART",
          missing_evidence: [],
          admitted_mode: nil
        )

      missing == [] ->
        build_state(scenario,
          classification: "KNOWN",
          standing: "ALIVE",
          confidence_basis: "DETERMINISTIC_RULE_AND_REQUIRED_EVIDENCE",
          missing_evidence: [],
          admitted_mode: scenario.candidate_mode
        )

      true ->
        build_state(scenario,
          classification: "PARTIAL",
          standing: "PARTIAL_ALIVE",
          confidence_basis: "DETERMINISTIC_RULE_INCOMPLETE_EVIDENCE",
          missing_evidence: missing,
          admitted_mode: nil
        )
    end
  end

  def seed_ocel!(id) do
    scenario = Map.fetch!(@scenarios, id)
    state = presentation_state(id)
    run = Ash.UUID.generate()

    objects = %{
      case: register!("FailureCase", "#{run}:case"),
      drive: register!("Drive", "#{run}:drive:SN-0001"),
      lot: register!("Lot", "#{run}:lot:L-42"),
      supplier: register!("Supplier", "#{run}:supplier:S-7"),
      bom: register!("BOMRevision", "#{run}:bom:BOM-9"),
      firmware: register!("FirmwareRevision", "#{run}:fw:FW-3.14"),
      station: register!("TestStation", "#{run}:station:TS-12"),
      standard: register!("StandardWork", "#{run}:standard:CS2-V1")
    }

    evidence =
      Enum.map(scenario.evidence, fn evidence_id ->
        register!("EvidenceArtifact", "#{run}:evidence:#{evidence_id}")
      end)

    relate!(objects.case, objects.drive, "investigates")
    relate!(objects.drive, objects.lot, "manufactured_in")
    relate!(objects.lot, objects.supplier, "supplied_by")
    relate!(objects.drive, objects.bom, "built_to")
    relate!(objects.drive, objects.firmware, "runs_firmware")
    relate!(objects.drive, objects.station, "tested_at")
    relate!(objects.case, objects.standard, "evaluated_against")
    Enum.each(evidence, &relate!(objects.case, &1, "supported_by"))

    observed =
      record_event!(
        "failure_observed",
        "#{run}:event:observed",
        [
          objects.case,
          objects.drive,
          objects.lot,
          objects.supplier,
          objects.bom,
          objects.firmware,
          objects.station
        ] ++ evidence,
        %{"symptom" => scenario.symptom}
      )

    triaged =
      record_event!(
        "triage_constructed",
        "#{run}:event:triage",
        [objects.case, objects.drive, objects.standard] ++ evidence,
        %{
          "classification" => state.classification,
          "standing" => state.standing,
          "candidate_mode" => scenario.candidate_mode,
          "admitted_mode" => state.admitted_mode,
          "authority" => state.authority,
          "human_gate" => state.human_gate
        }
      )

    {:ok, projection} = Projection.project([observed.id, triaged.id])

    %{run_id: run, state: state, projection: projection}
  end

  defp build_state(scenario, overrides) do
    base = %{
      title: scenario.title,
      symptom: scenario.symptom,
      evidence: scenario.evidence,
      required_evidence: scenario.required,
      missing_evidence: [],
      classification: "UNKNOWN",
      standing: "UNKNOWN",
      candidate_mode: scenario.candidate_mode,
      admitted_mode: nil,
      confidence_basis: "UNCLASSIFIED",
      next_action: scenario.next_action,
      owning_team: scenario.owning_team,
      prior_cases: scenario.prior_cases,
      human_gate: "ENGINEER_DISPOSITION_REQUIRED",
      authority: "SELECT_CONSTRUCT_ONLY",
      ranked_hypotheses: ranked_hypotheses(scenario)
    }

    Enum.into(overrides, base)
  end

  defp ranked_hypotheses(scenario) do
    primary_score = if scenario.prior_cases == [], do: 0.68, else: 0.94

    [
      %{
        mode: scenario.candidate_mode,
        score: primary_score,
        admitted: false,
        evidence: scenario.evidence,
        prior_cases: scenario.prior_cases
      },
      %{
        mode: "MODE-B-SUPPLIER",
        score: 0.31,
        admitted: false,
        evidence: ["lot_genealogy"],
        prior_cases: ["FA-2023-0088"]
      }
    ]
  end

  defp register!(type, ocel_id) do
    Object
    |> Ash.Changeset.for_create(:register, %{object_type: type, ocel_id: ocel_id})
    |> Ash.create!(authorize?: false)
  end

  defp relate!(source, target, qualifier) do
    ObjectObject
    |> Ash.Changeset.for_create(:relate, %{
      source_object_id: source.id,
      target_object_id: target.id,
      qualifier: qualifier
    })
    |> Ash.create!(authorize?: false)
  end

  defp record_event!(event_type, ocel_id, objects, attributes) do
    Event
    |> Ash.Changeset.for_create(:record, %{
      event_type: event_type,
      ocel_id: ocel_id,
      occurred_at: DateTime.utc_now(),
      attributes: attributes,
      object_relations:
        Enum.map(objects, fn object ->
          %{object_id: object.id, qualifier: "subject"}
        end)
    })
    |> Ash.create!(authorize?: false)
  end
end
