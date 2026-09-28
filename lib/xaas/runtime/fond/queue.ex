defmodule Xaas.Runtime.FOND.Queue do
  def new, do: :queue.new()
  def push(q, x), do: :queue.in(x, q)

  def pop(q),
    do:
      (case :queue.out(q) do
         {{:value, x}, q2} -> {:ok, x, q2}
         {:empty, _} -> {:empty, q}
       end)
end
