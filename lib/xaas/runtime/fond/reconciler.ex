defmodule Xaas.Runtime.FOND.Reconciler do
  def reconcile(g, h),
    do:
      Enum.reduce(h, g, fn {id, s}, a ->
        if s in [:down, :refused], do: Xaas.Runtime.FOND.Graph.exclude(a, id), else: a
      end)
end
