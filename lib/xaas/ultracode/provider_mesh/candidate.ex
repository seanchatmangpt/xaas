defmodule Xaas.Ultracode.ProviderMesh.Candidate do
@moduledoc "Provider-mesh runtime primitive."
defstruct [:id,:module,:priority,:weight,:metadata]
def new(id,m,o \\ []), do: %__MODULE__{id:id,module:m,priority:Keyword.get(o,:priority,100),weight:Keyword.get(o,:weight,1),metadata:Keyword.get(o,:metadata,%{})}
end
