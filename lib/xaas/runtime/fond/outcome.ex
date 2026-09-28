defmodule Xaas.Runtime.FOND.Outcome do
  def classify({:ok, _} = x), do: x
  def classify({:error, {:local, r}}), do: {:fail_local, r}
  def classify({:error, r}), do: {:fail_edge, r}
  def classify(x), do: {:ok, x}
end
