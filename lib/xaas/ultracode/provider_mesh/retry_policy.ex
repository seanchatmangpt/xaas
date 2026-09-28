defmodule Xaas.Ultracode.ProviderMesh.RetryPolicy do
@moduledoc "Provider-mesh runtime primitive."
defstruct max_attempts: 1
def retry?(%__MODULE__{max_attempts: m},a,class), do: a<m and class==:transient
end
