defmodule Xaas.Runtime.FOND.Lease do
  defstruct [:key, :owner, :expires_at]

  def new(k, o, ttl),
    do: %__MODULE__{key: k, owner: o, expires_at: System.monotonic_time(:millisecond) + ttl}

  def valid?(l), do: System.monotonic_time(:millisecond) < l.expires_at
end
