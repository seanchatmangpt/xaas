defmodule Xaas.Runtime.FOND.Backoff do
  def delay(n, base \\ 25, cap \\ 5000), do: min(cap, trunc(base * :math.pow(2, n)))
end
