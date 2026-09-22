defmodule Xaas.CaseStudies.WdFa.ContextEnvelope do
  @moduledoc """
  Stable deep-link context envelope for WD CS2 views.

  The envelope is sufficient to reconstruct the semantic subject without
  scraping presentation text. It remains a projection and grants no authority.
  """

  alias Xaas.CaseStudies.WdFa
  alias Xaas.CaseStudies.WdFa.{SemanticWork, Stogaf}

  @viewpoints ~w(fa-engineer fa-manager executive architecture assessment)

  @spec build(String.t(), String.t(), boolean()) :: {:ok, map()} | {:error, term()}
  def build(case_id, viewpoint, experience_admitted? \\ false)

  def build(case_id, viewpoint, experience_admitted?) when viewpoint in @viewpoints do
    state = WdFa.presentation_state(case_id, experience_admitted?)
    work = SemanticWork.for_case(case_id, experience_admitted?)
    architecture = Stogaf.demo_projection()

    {:ok,
     %{
       schema: "WD_FA_CONTEXT_ENVELOPE_V1",
       canonical_subject: "urn:xaas:wd-cs2:case:" <> case_id,
       case_id: case_id,
       viewpoint: viewpoint,
       classification: state.classification,
       standing: state.standing,
       admitted_mode: state.admitted_mode,
       evidence_ids: state.evidence,
       prior_cases: state.prior_cases,
       work_identity: work.id,
       work_standing: work.standing,
       authority_ceiling: architecture.authority,
       human_gate: architecture.human_gate,
       evidence_ceiling: architecture.evidence_ceiling,
       replay_identity: replay_identity(case_id, experience_admitted?)
     }}
  rescue
    KeyError -> {:error, :unknown_case}
  end

  def build(_case_id, _viewpoint, _experience_admitted?),
    do: {:error, :unknown_viewpoint}

  @spec viewpoints() :: [String.t()]
  def viewpoints, do: @viewpoints

  defp replay_identity("novel_x", true), do: "NOVEL-X-REPLAY"
  defp replay_identity(_case_id, _experience_admitted?), do: nil
end
