defmodule Xaas.Ultracode.ProviderMesh.ProviderPool do
  @moduledoc "Provider-mesh runtime primitive."
  def available(cs, h),
    do:
      Enum.filter(cs, fn c ->
        case Map.get(h, c.id) do
          %{status: :unhealthy} -> false
          _ -> true
        end
      end)
end
