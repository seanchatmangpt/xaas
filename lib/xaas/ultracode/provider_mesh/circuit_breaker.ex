defmodule Xaas.Ultracode.ProviderMesh.CircuitBreaker do
  @moduledoc "Provider mesh runtime primitive."
  defstruct failures: %{}, opened: %{}, threshold: 3, cooldown_ms: 30_000

  def available?(s, id, now \\ System.monotonic_time(:millisecond)),
    do:
      (case s.opened[id] do
         nil -> true
         at -> now - at >= s.cooldown_ms
       end)

  def success(s, id),
    do: %{s | failures: Map.delete(s.failures, id), opened: Map.delete(s.opened, id)}
end
