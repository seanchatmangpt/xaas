defmodule Xaas.Runtime.FOND.Transition do
  def apply(s, {:exclude, id}), do: %{s | graph: Xaas.Runtime.FOND.Graph.exclude(s.graph, id)}

  def apply(s, {:attempted, e}),
    do: %{s | attempts: s.attempts + 1, trace: Xaas.Runtime.FOND.Trace.add(s.trace, e)}
end
