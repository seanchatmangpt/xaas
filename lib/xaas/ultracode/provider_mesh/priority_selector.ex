defmodule Xaas.Ultracode.ProviderMesh.PrioritySelector do
@moduledoc "Provider-mesh runtime primitive."
def select(cs), do: Enum.sort_by(cs,&{&1.priority,&1.id})
end
