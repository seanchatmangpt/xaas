defmodule Xaas.SelfDigest.Shadow do
  @enforce_keys [:subject, :base]
  defstruct [:subject, :base, operations: [], result: nil, status: :open]

  def open(subject, base), do: %__MODULE__{subject: subject, base: base}

  def append(%__MODULE__{status: :open} = shadow, operation),
    do: %{shadow | operations: shadow.operations ++ [operation]}

  def materialize(%__MODULE__{status: :open} = shadow, reducer) do
    case Enum.reduce_while(shadow.operations, {:ok, shadow.base}, fn operation, {:ok, acc} ->
           case reducer.(operation, acc) do
             {:ok, next} -> {:cont, {:ok, next}}
             {:error, reason} -> {:halt, {:error, reason}}
           end
         end) do
      {:ok, result} -> {:ok, %{shadow | result: result, status: :materialized}}
      {:error, reason} -> {:error, %{shadow | status: {:refused, reason}}}
    end
  end
end
