defmodule Xaas.Ultracode.ProviderMesh.Contract do
@moduledoc "Provider-mesh runtime primitive."
def validate(%{id: _,module: _}=m), do: {:ok,m}
def validate(m) when is_map(m), do: {:error,:missing_provider_fields}
def validate(_), do: {:error,:invalid_provider_contract}
end
