defmodule Xaas.CaseStudies.WdFa.CapabilitySelector do
  @moduledoc """
  Deterministic SA2A capability selection for WD CS2 fixture states.

  The selector returns capability identifiers only. It does not execute
  consequential operations or grant authority.
  """

  alias Xaas.CaseStudies.WdFa
  alias Xaas.CaseStudies.WdFa.Stogaf.Capabilities

  @common ~w(
    reconstruct_subject
    retrieve_prior_cases
    rank_hypotheses
    test_applicability
    construct_diagnostic_work
    project_sjira
    project_view
  )

  @spec for_case(String.t(), boolean()) :: [map()]
  def for_case(case_id, experience_admitted? \\ false) do
    _state = WdFa.presentation_state(case_id, experience_admitted?)
    allowed = MapSet.new(@common)

    Capabilities.friday()
    |> Enum.filter(&MapSet.member?(allowed, &1.id))
  end
end
