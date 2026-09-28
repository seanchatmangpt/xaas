defmodule Xaas.Runtime.ProviderFabric.Health do
  @moduledoc "Provider fabric health primitive."
  defstruct status: :unknown, latency_ms: nil
  def usable?(h), do: h.status in [:unknown, :healthy, :degraded]
end
