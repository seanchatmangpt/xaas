defmodule Xaas.Runtime.ProviderFabric.Backoff do
  @moduledoc "Provider fabric backoff primitive."
  defstruct base_ms: 25, cap_ms: 2_000
  def delay(b,n), do: min(b.cap_ms,trunc(b.base_ms*:math.pow(2,n)))
end
