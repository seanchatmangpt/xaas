defmodule Xaas.Trimtab.ModelRole do
  @enforce_keys [:provider, :model]
  defstruct [:provider, :model, authority: :none]
  def new(p, m) when is_binary(p) and is_binary(m), do: {:ok, %__MODULE__{provider: p, model: m}}
  def new(_, _), do: {:error, :invalid_model}
  def authority?(%__MODULE__{authority: :none}), do: false
end
