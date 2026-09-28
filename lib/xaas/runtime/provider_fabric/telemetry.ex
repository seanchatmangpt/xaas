defmodule Xaas.Runtime.ProviderFabric.Telemetry do
  @moduledoc "Provider fabric telemetry primitive."
  defstruct prefix: [:xaas,:runtime,:provider_fabric]
  def event(t,e), do: t.prefix++[e]
end
