defmodule Xaas.Runtime.FOND.Capability do
  def normalize(c) when is_atom(c), do: c

  def normalize(c) when is_binary(c),
    do: c |> String.trim() |> String.downcase() |> String.replace("-", "_") |> String.to_atom()
end
