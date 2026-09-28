defmodule Xaas.Runtime.ProviderFabric.Lease do
  @moduledoc "Provider fabric lease primitive."
  defstruct id: nil, owner: nil, expires_at: 0
  def valid?(l, now), do: now < l.expires_at
end
