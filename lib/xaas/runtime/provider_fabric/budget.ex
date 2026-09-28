defmodule Xaas.Runtime.ProviderFabric.Budget do
  @moduledoc "Provider fabric budget primitive."
  defstruct attempts: 8
  def consume(%__MODULE__{attempts: n}=b) when n>0, do: {:ok,%{b|attempts: n-1}}
    def consume(_), do: {:error,:exhausted}
end
