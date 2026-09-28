defmodule Xaas.Runtime.ProviderFabric.FailureSet do
  @moduledoc "Provider fabric failure_set primitive."
  defstruct edges: MapSet.new()
  def add(f,id), do: %{f|edges:MapSet.put(f.edges,id)}
    def failed?(f,id), do: MapSet.member?(f.edges,id)
end
