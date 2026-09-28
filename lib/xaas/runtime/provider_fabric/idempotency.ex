defmodule Xaas.Runtime.ProviderFabric.Idempotency do
  @moduledoc "Provider fabric idempotency primitive."
  defstruct key: nil
  def new(v), do: %__MODULE__{key: Base.encode16(:crypto.hash(:sha256,:erlang.term_to_binary(v)),case: :lower)}
end
