defmodule Xaas.Runtime.FOND.Circuit do
  defstruct failures: %{}, threshold: 3
  def new(t \\ 3), do: %__MODULE__{threshold: t}
  # W659 dual-safe: explicit absent-key arm (seed 1, no fun call — matches
  # Map.update/4 otp-28 semantics) and present-key arm (increment).
  def fail(c, id),
    do: %{c | failures: bump(c.failures, id)}

  defp bump(m, id) do
    case Map.fetch(m, id) do
      {:ok, n} -> Map.put(m, id, n + 1)
      :error -> Map.put(m, id, 1)
    end
  end
  def open?(c, id), do: Map.get(c.failures, id, 0) >= c.threshold
  def reset(c, id), do: %{c | failures: Map.delete(c.failures, id)}
end
