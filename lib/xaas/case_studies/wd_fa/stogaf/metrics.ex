defmodule Xaas.CaseStudies.WdFa.Stogaf.Metrics do
  @moduledoc false

  alias Xaas.CaseStudies.WdFa.Stogaf.{Conformance, Requirements, Viewpoints, WorkGraph}

  @spec summary() :: map()
  def summary do
    %{
      requirements_mapped: Requirements.mapped_count(),
      viewpoints: Viewpoints.count(),
      work_orders: WorkGraph.count(),
      production_levels_unclaimed: Conformance.production_unknown_count(),
      known_class_llm_target: "0 general LLM calls",
      human_implementation_transition_target: "→ 0",
      recurring_class_mechanization_target: "→ 1"
    }
  end
end
