defmodule Xaas.Runtime.ProviderFabric.Trace do
  @moduledoc "Provider fabric trace primitive."
  defstruct events: []
  def add(t, e), do: %{t | events: t.events ++ [e]}
end
