defmodule Xaas.Runtime.ProviderFabric.Edge do
  @enforce_keys [:id, :provider, :capabilities]
  defstruct [:id, :provider, :capabilities, priority: 0, weight: 1, metadata: %{}]

  def new(id, provider, capabilities, opts \\ []) when is_list(capabilities) do
    %__MODULE__{
      id: id,
      provider: provider,
      capabilities: MapSet.new(capabilities),
      priority: Keyword.get(opts, :priority, 0),
      weight: Keyword.get(opts, :weight, 1),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  def supports?(%__MODULE__{capabilities: caps}, capability),
    do: MapSet.member?(caps, capability)
end
