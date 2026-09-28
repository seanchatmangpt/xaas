defmodule Xaas.ResearchRuntime.PlanningWaveTest do
  @moduledoc false
  def case(edges, failed) when failed in edges, do: {:ok, Enum.reject(edges, &(&1 == failed))}
  def case(edges, failed), do: {:refused, :boundary_violation}
end
