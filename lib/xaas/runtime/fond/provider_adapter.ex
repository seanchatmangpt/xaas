defmodule Xaas.Runtime.FOND.ProviderAdapter do
  def edge(id, m, cost \\ 1),
    do:
      Xaas.Runtime.FOND.Edge.new(id, fn {c, i} -> m.invoke(c, i) end,
        capabilities: m.capabilities(),
        cost: cost
      )
end
