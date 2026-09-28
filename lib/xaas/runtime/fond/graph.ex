defmodule Xaas.Runtime.FOND.Graph do
 defstruct edges: %{}, excluded: MapSet.new()
 def new(es \\ []), do: Enum.reduce(es,%__MODULE__{},&put(&2,&1))
 def put(g,e), do: %{g|edges:Map.put(g.edges,e.id,e)}
 def exclude(g,id), do: %{g|excluded:MapSet.put(g.excluded,id)}
 def reachable(g), do: g.edges |> Map.reject(fn {id,_}->MapSet.member?(g.excluded,id) end) |> Map.values()
end
