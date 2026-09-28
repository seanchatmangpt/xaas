defmodule Xaas.Ultracode.ProviderMesh.Provider do
  @moduledoc "Provider-mesh runtime primitive."
  @callback id() :: String.t()
  @callback capabilities() :: [atom()]
  @callback invoke(atom(), term(), keyword()) :: {:ok, term()} | {:error, term()}
end
