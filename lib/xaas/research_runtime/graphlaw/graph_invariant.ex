defmodule Xaas.ResearchRuntime.GraphInvariant do
  @moduledoc false
  def check(nodes, edges) when is_list(nodes) and is_list(edges), do: {:ok, Enum.all?(edges, fn {a,b} -> a in nodes and b in nodes end)}
  def check(nodes, edges), do: {:refused, :boundary_violation}
end
