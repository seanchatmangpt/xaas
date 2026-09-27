defmodule Xaas.Ultracode.ProviderMesh.TimeoutPolicy do
@moduledoc "Provider-mesh runtime primitive."
defstruct timeout_ms: 30_000
def deadline(%__MODULE__{timeout_ms:ms}), do: System.monotonic_time(:millisecond)+ms
def expired?(d), do: System.monotonic_time(:millisecond)>=d
end
