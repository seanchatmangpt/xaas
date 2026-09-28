defmodule Xaas.Ultracode.ProviderMesh.Outcome do
@moduledoc "Provider-mesh runtime primitive."
def normalize({:ok,v}), do: {:ok,v}
def normalize({:error,r}), do: {:error,r}
def normalize(x), do: {:error,{:invalid_provider_outcome,x}}
end
