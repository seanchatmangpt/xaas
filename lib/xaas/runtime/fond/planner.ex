defmodule Xaas.Runtime.FOND.Planner do
 def plan(g,cs), do: Enum.map(cs,fn c->{c,Xaas.Runtime.FOND.Selector.candidates(g,c)|>Enum.map(& &1.id)} end)
end
