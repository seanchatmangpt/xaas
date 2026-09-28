defmodule Xaas.Runtime.ProviderFabric.Provider do
  @moduledoc "Provider fabric provider primitive."
  defstruct module: nil, capabilities: MapSet.new()
  def supports?(p,c), do: MapSet.member?(p.capabilities,c)
end
