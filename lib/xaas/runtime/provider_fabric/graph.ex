defmodule Xaas.Runtime.ProviderFabric.Graph do
  @moduledoc "Provider fabric graph primitive."
  defstruct edges: %{}, excluded: MapSet.new()
  def new, do: %__MODULE__{}
end
