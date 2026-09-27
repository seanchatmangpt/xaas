defmodule Xaas.Ultracode.ProviderMesh.RoundRobin do
@moduledoc "Provider-mesh runtime primitive."
def select([],_), do: {nil,0}
def select(cs,cursor) do i=rem(max(cursor,0),length(cs)); {Enum.at(cs,i),i+1} end
end
