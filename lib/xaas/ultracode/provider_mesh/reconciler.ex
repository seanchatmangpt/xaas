defmodule Xaas.Ultracode.ProviderMesh.Reconciler do
  @moduledoc "Provider mesh runtime primitive."
  alias Xaas.Ultracode.ProviderMesh.HealthSnapshot

  def observe(cs),
    do:
      Enum.map(cs, fn c ->
        result =
          if function_exported?(c.module, :health, 0),
            do: c.module.health(),
            else: {:error, :health_unavailable}

        case result do
          {:ok, d} -> HealthSnapshot.healthy(c.id, d)
          {:error, r} -> HealthSnapshot.unhealthy(c.id, r)
          other -> HealthSnapshot.unhealthy(c.id, {:invalid_health, other})
        end
      end)
end
