defmodule Xaas.Ultracode.ProviderMesh.Telemetry do
  @moduledoc "Provider-mesh runtime primitive."
  def event(n, m \\ %{}),
    do: :telemetry.execute([:xaas, :ultracode, :provider_mesh, n], %{count: 1}, m)
end
