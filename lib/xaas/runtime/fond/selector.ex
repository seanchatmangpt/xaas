defmodule Xaas.Runtime.FOND.Selector do
 def candidates(g,c), do: g |> Xaas.Runtime.FOND.Graph.reachable() |> Enum.filter(&Xaas.Runtime.FOND.Edge.supports?(&1,c)) |> Enum.sort_by(&{&1.cost,to_string(&1.id)})
 def next(g,c), do: (case candidates(g,c) do [h|_]->{:ok,h}; []->{:error,:no_reachable_edge} end)
end
