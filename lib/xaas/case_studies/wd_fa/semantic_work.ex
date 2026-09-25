defmodule Xaas.CaseStudies.WdFa.SemanticWork do
  @moduledoc """
  sJira-shaped semantic work projection for WD CS2 fixture states.

  Work orders are projections of deterministic case state. They grant no
  consequential authority.
  """

  alias Xaas.CaseStudies.WdFa

  @spec for_case(String.t(), boolean()) :: map()
  def for_case(case_id, experience_admitted? \\ false) do
    state = WdFa.presentation_state(case_id, experience_admitted?)

    %{
      id: "WO-" <> String.upcase(case_id),
      subject: case_id,
      classification: state.classification,
      standing: work_standing(state),
      obligation: obligation(state),
      owner: state.owning_team,
      next_action: state.next_action,
      required_evidence: state.missing_evidence,
      supporting_evidence: state.evidence,
      authority: "SELECT_CONSTRUCT_ONLY",
      human_gate: state.human_gate
    }
  end

  defp work_standing(%{classification: "KNOWN"}), do: "READY_FOR_ENGINEER_DISPOSITION"
  defp work_standing(%{classification: "PARTIAL"}), do: "BLOCKED_ON_EVIDENCE"
  defp work_standing(%{classification: "UNKNOWN"}), do: "NOVEL_INVESTIGATION_REQUIRED"

  defp obligation(%{classification: "KNOWN", next_action: action}),
    do: "prepare known-path action: " <> action

  defp obligation(%{classification: "PARTIAL", missing_evidence: missing}),
    do: "acquire required evidence: " <> Enum.join(missing, ",")

  defp obligation(%{classification: "UNKNOWN"}),
    do: "open bounded novel-failure investigation"
end
