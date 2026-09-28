defmodule Xaas.Runtime.ProviderFabric.CapabilitySet do
  @moduledoc "Provider fabric capability_set primitive."
  defstruct values: MapSet.new()
  def covers?(c, n), do: MapSet.subset?(MapSet.new(n), c.values)
end
