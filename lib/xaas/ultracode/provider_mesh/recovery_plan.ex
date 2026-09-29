defmodule Xaas.Ultracode.ProviderMesh.RecoveryPlan do
  @moduledoc "Provider-mesh runtime primitive."
  defstruct [:capability, attempted: [], remaining: [], failures: []]
  def new(c, cs), do: %__MODULE__{capability: c, remaining: Enum.map(cs, & &1.id)}

  def fail(p, id, r),
    do: %{
      p
      | attempted: p.attempted ++ [id],
        remaining: List.delete(p.remaining, id),
        failures: p.failures ++ [{id, r}]
    }
end
