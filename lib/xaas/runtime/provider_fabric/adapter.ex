defmodule Xaas.Runtime.ProviderFabric.Adapter do
  @moduledoc "Provider fabric adapter primitive."
  defstruct provider: nil
  def dispatch(a,c,p,o \\ []), do: a.provider.dispatch(c,p,o)
end
