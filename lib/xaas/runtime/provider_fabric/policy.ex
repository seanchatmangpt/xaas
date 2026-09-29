defmodule Xaas.Runtime.ProviderFabric.Policy do
  @moduledoc "Provider fabric policy primitive."
  defstruct max_attempts: 8, timeout_ms: 30_000
  def allows?(p, n), do: n < p.max_attempts
end
