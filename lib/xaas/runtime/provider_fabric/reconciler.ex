defmodule Xaas.Runtime.ProviderFabric.Reconciler do
  @moduledoc "Provider fabric reconciler primitive."
  defstruct excluded: MapSet.new()
  def unhealthy(r,id), do: %{r|excluded:MapSet.put(r.excluded,id)}
end
