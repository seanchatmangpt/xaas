defmodule Xaas.Ultracode.ProviderMesh.HealthSnapshot do
@moduledoc "Provider-mesh runtime primitive."
defstruct [:provider_id,:status,:observed_at,:detail]
def healthy(id,d \\ nil), do: %__MODULE__{provider_id: id,status: :healthy,detail: d,observed_at: System.monotonic_time(:millisecond)}
def unhealthy(id,d), do: %__MODULE__{provider_id: id,status: :unhealthy,detail: d,observed_at: System.monotonic_time(:millisecond)}
end
