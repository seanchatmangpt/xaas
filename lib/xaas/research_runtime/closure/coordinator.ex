defmodule Xaas.ResearchRuntime.Coordinator do
  @moduledoc false
  def route(envelope, edges) when is_list(edges) and edges != [], do: {:ok, %{envelope: envelope, edge: hd(edges)}}
  def route(envelope, edges), do: {:refused, :boundary_violation}
end
