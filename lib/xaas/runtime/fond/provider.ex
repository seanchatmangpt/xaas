defmodule Xaas.Runtime.FOND.Provider do
  @callback capabilities() :: [atom()]
  @callback invoke(atom(), term()) :: {:ok, term()} | {:error, term()}
  @callback health() :: term()
end
