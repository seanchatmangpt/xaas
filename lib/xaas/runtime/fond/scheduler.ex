defmodule Xaas.Runtime.FOND.Scheduler do
 def order(xs), do: Enum.sort_by(xs,fn x->{Map.get(x,:priority,100),Map.get(x,:id)} end)
 def take(xs,n), do: xs |> order() |> Enum.take(n)
end
