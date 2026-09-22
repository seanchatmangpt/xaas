defmodule Xaas.CaseStudies.WdFa.Evaluation do
  @moduledoc """
  Offline repository-local evaluation for the WD CS2 reference.

  Production metrics are deliberately reported as UNMEASURED.
  """

  alias Xaas.CaseStudies.WdFa
  alias Xaas.CaseStudies.WdFa.{LearningLoop, VerificationReceipt}

  @spec offline_report() :: map()
  def offline_report do
    known = WdFa.presentation_state("known_firmware")
    partial = WdFa.presentation_state("partial_firmware")
    novel = WdFa.presentation_state("novel_x")
    learned = WdFa.presentation_state("novel_x", true)

    {:ok, %{receipt: receipt}} = LearningLoop.verify_novel_fixture()
    tampered = %{receipt | observed_disposition: "TAMPERED"}

    self_certification_refused =
      match?(
        {:error, :self_certification_refused},
        VerificationReceipt.issue(%{
          case_id: "novel_x",
          candidate_standing: "UNKNOWN",
          observed_disposition: "MODE-X-NOVEL",
          evidence_ids: novel.evidence,
          producer_id: "same",
          verifier_id: "same"
        })
      )

    controls = [
      control("known-admitted", known.classification == "KNOWN" and known.admitted_mode != nil),
      control("partial-unadmitted", partial.classification == "PARTIAL" and is_nil(partial.admitted_mode)),
      control("novel-remains-unknown", novel.classification == "UNKNOWN" and is_nil(novel.admitted_mode)),
      control("self-certification-refused", self_certification_refused),
      control("tampered-receipt-refused", not VerificationReceipt.verify(tampered)),
      control("verified-replay-known", learned.classification == "KNOWN" and learned.admitted_mode == "MODE-X-NOVEL")
    ]

    %{
      evidence_ceiling: "REPO_LOCAL_FIXTURE",
      controls: controls,
      controls_passed: Enum.count(controls, & &1.passed),
      controls_total: length(controls),
      all_controls_passed: Enum.all?(controls, & &1.passed),
      production_metrics: %{
        mttr: "UNMEASURED",
        false_known_rate: "UNMEASURED",
        false_unknown_rate: "UNMEASURED",
        engineer_touches: "UNMEASURED",
        machine_experience_reuse_rate: "UNMEASURED"
      }
    }
  end

  defp control(id, passed), do: %{id: id, passed: passed}
end
