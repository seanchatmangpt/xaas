defmodule Xaas.Trimtab.ContextBudget do
  @enforce_keys [:max_items, :max_bytes]
  defstruct [:max_items, :max_bytes]

  def new(i, b) when is_integer(i) and i > 0 and is_integer(b) and b > 0,
    do: {:ok, %__MODULE__{max_items: i, max_bytes: b}}

  def new(_, _), do: {:error, :invalid_budget}

  def fit?(b, xs),
    do: length(xs) <= b.max_items and byte_size(:erlang.term_to_binary(xs)) <= b.max_bytes
end
