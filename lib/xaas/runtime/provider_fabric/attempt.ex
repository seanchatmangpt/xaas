defmodule Xaas.Runtime.ProviderFabric.Attempt do
  @moduledoc "Provider fabric attempt primitive."
  defstruct edge_id: nil, number: 0, outcome: nil
  def finish(a, o), do: %{a | outcome: o}
end
