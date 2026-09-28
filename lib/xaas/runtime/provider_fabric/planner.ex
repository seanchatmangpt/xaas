defmodule Xaas.Runtime.ProviderFabric.Planner do
  @moduledoc "Provider fabric planner primitive."
  defstruct capabilities: []
  def feasible?(p,a), do: Enum.all?(p.capabilities,&(&1 in a))
end
