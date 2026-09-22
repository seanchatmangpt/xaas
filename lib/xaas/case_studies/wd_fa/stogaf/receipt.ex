defmodule Xaas.CaseStudies.WdFa.Stogaf.Receipt do
  @moduledoc """
  Deterministic repository-local receipt for the WD CS2 STOGAF architecture episode.

  The receipt reports architecture/conformance evidence only. It does not grant
  production authority or external standing.
  """

  alias Xaas.CaseStudies.WdFa.Stogaf
  alias Xaas.CaseStudies.WdFa.Stogaf.{
    Capabilities,
    Conformance,
    Metrics,
    Requirements,
    Viewpoints,
    WorkGraph
  }

  @spec build(String.t()) :: map()
  def build(subject_sha) when is_binary(subject_sha) and byte_size(subject_sha) > 0 do
    projection = Stogaf.demo_projection()

    %{
      schema: "STOGAF_WD_CS2_RECEIPT_V1",
      subject_sha: subject_sha,
      rfc: projection.rfc,
      equation: projection.equation,
      current_conformance: Conformance.current(),
      target_conformance: Conformance.target(),
      evidence_ceiling: projection.evidence_ceiling,
      authority: projection.authority,
      human_gate: projection.human_gate,
      requirements_mapped: Requirements.mapped_count(),
      viewpoints: Viewpoints.count(),
      work_orders: WorkGraph.count(),
      friday_capabilities: length(Capabilities.friday()),
      friday_do_capabilities: Capabilities.friday_do_count(),
      production_levels_unclaimed: Conformance.production_unknown_count(),
      known_path_general_llm_required: Capabilities.known_path_general_llm_required?(),
      dfcm: Metrics.summary(),
      standing: "REPO_LOCAL_ARCHITECTURE_RECEIPT"
    }
  end
end
