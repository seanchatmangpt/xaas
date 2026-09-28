defmodule Xaas.Runtime.FOND.Executor do
 alias Xaas.Runtime.FOND.{Graph,Selector,Outcome}
 def run(g,c,i), do: loop(g,c,i,[])
 defp loop(g,c,i,t), do: (case Selector.next(g,c) do {:error,_}->{:exhausted,Enum.reverse(t),g}; {:ok,e}->case Outcome.classify(e.invoke.(i)) do {:ok,v}->{:ok,v,e.id,g}; {:fail_local,r}->{:fail_local,e.id,r,g}; {:fail_edge,r}->loop(Graph.exclude(g,e.id),c,i,[{e.id,r}|t]) end end)
end
