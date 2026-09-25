defmodule Xaas.CaseStudies.WdFa.Stogaf.Capabilities do
  @moduledoc """
  Bounded capability catalog for the WD CS2 STOGAF episode.

  The Friday admissible set contains OBSERVE, SELECT and CONSTRUCT only.
  Production DO remains outside the episode's evidence ceiling.
  """

  @capabilities [
    %{id: "reconstruct_subject", plane: "OBSERVE", authority: "NONE", intelligence: "NONE"},
    %{
      id: "retrieve_prior_cases",
      plane: "OBSERVE",
      authority: "NONE",
      intelligence: "OPTIONAL_RETRIEVAL"
    },
    %{
      id: "rank_hypotheses",
      plane: "SELECT",
      authority: "NONE",
      intelligence: "BOUNDED_MODEL_ALLOWED"
    },
    %{id: "test_applicability", plane: "SELECT", authority: "NONE", intelligence: "NONE"},
    %{
      id: "construct_diagnostic_work",
      plane: "CONSTRUCT",
      authority: "NONE",
      intelligence: "NONE"
    },
    %{id: "project_sjira", plane: "CONSTRUCT", authority: "NONE", intelligence: "NONE"},
    %{id: "project_view", plane: "CONSTRUCT", authority: "NONE", intelligence: "NONE"},
    %{id: "verify_receipt", plane: "OBSERVE", authority: "NONE", intelligence: "NONE"},
    %{
      id: "compile_machine_experience",
      plane: "CONSTRUCT",
      authority: "VERIFIED_INPUT_REQUIRED",
      intelligence: "NONE"
    }
  ]

  @production_do %{
    id: "production_do",
    plane: "DO",
    authority: "OUTSIDE_FRIDAY_SCOPE",
    intelligence: "N/A"
  }

  @spec friday() :: [map()]
  def friday, do: @capabilities

  @spec production_do() :: map()
  def production_do, do: @production_do

  @spec friday_do_count() :: non_neg_integer()
  def friday_do_count, do: Enum.count(@capabilities, &(&1.plane == "DO"))

  @spec known_path_general_llm_required?() :: boolean()
  def known_path_general_llm_required?, do: false
end
