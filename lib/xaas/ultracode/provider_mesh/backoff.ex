defmodule Xaas.Ultracode.ProviderMesh.Backoff do
  @moduledoc "Provider mesh runtime primitive."
  def delay(attempt, base \\ 100, max_ms \\ 30_000),
    do: min(max_ms, round(base * :math.pow(2, max(attempt - 1, 0))))
end
