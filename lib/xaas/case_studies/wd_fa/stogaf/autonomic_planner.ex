defmodule Xaas.CaseStudies.WdFa.Stogaf.AutonomicPlanner do
  @moduledoc """
  Deterministic sJira work selector for the STOGAF WD CS2 closure graph.

  Selection depends only on declared dependencies and admitted work standing.
  It invokes no LLM and grants no authority.
  """

  alias Xaas.CaseStudies.WdFa.Stogaf.WorkGraph

  @spec initial_standings() :: map()
  def initial_standings do
    Map.new(WorkGraph.all(), &{&1.id, "UNKNOWN"})
  end

  @spec next(map()) :: {:work, map()} | {:blocked, [String.t()]} | :complete
  def next(standings) when is_map(standings) do
    pending = Enum.filter(WorkGraph.all(), &(Map.get(standings, &1.id, "UNKNOWN") != "ALIVE"))

    case Enum.find(pending, &dependencies_alive?(&1, standings)) do
      nil ->
        if pending == [] do
          :complete
        else
          {:blocked, Enum.map(pending, & &1.id)}
        end

      order ->
        {:work,
         %{
           id: order.id,
           dependencies: order.deps,
           selection_basis: "LOWEST_DECLARED_ELIGIBLE_WORK_ORDER",
           runtime_intelligence: "NONE",
           authority: "SELECT_CONSTRUCT_ONLY"
         }}
    end
  end

  defp dependencies_alive?(order, standings) do
    Enum.all?(order.deps, &(Map.get(standings, &1) == "ALIVE"))
  end
end
