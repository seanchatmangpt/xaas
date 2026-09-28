defmodule Xaas.Ultracode.ProviderMesh.RouteDecision do
@moduledoc "Provider-mesh runtime primitive."
defstruct [:capability,candidates: [],excluded: []]
def exhausted?(%__MODULE__{candidates: []}), do: true
def exhausted?(_), do: false
end
