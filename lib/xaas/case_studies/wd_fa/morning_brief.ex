defmodule Xaas.CaseStudies.WdFa.MorningBrief do
  @moduledoc """
  Human-attention projection for the WD Case Study 2 demo.

  "Prior-art ready" means the system can prepare the known path from admitted
  evidence. It does not mean the case is consequentially closed; engineer
  disposition remains required.
  """

  alias Xaas.CaseStudies.WdFa

  @spec summary() :: map()
  def summary do
    states =
      WdFa.scenario_ids()
      |> Enum.map(&{&1, WdFa.presentation_state(&1)})

    %{
      needs_judgment: count_class(states, "UNKNOWN"),
      missing_evidence: count_class(states, "PARTIAL"),
      prior_art_ready: count_class(states, "KNOWN"),
      total_subjects: length(states),
      authority: "SELECT_CONSTRUCT_ONLY",
      human_gate: "ENGINEER_DISPOSITION_REQUIRED",
      semantic_rule:
        "Known work is prepared; consequential disposition remains with the engineer."
    }
  end

  defp count_class(states, classification) do
    Enum.count(states, fn {_id, state} -> state.classification == classification end)
  end
end
