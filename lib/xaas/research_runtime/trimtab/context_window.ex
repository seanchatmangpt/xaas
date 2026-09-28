defmodule Xaas.ResearchRuntime.ContextWindow do
  @moduledoc false
  def fit(items, limit) when is_list(items) and is_integer(limit) and limit >= 0, do: {:ok, Enum.take(items, limit)}
  def fit(items, limit), do: {:refused, :boundary_violation}
end
