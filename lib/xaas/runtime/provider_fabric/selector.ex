defmodule Xaas.Runtime.ProviderFabric.Selector do
  @moduledoc "Provider fabric selector primitive."
  defstruct strategy: :priority
  def choose([]), do: {:error, :exhausted}
  def choose([h | _]), do: {:ok, h}
end
