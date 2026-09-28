defmodule Xaas.Ultracode.ProviderMesh.Exclusion do
@moduledoc "Provider-mesh runtime primitive."
defstruct [:provider_id,:reason,:at]
def new(id,r), do: %__MODULE__{provider_id: id,reason: r,at: System.monotonic_time(:millisecond)}
end
