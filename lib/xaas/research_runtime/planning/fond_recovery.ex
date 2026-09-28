defmodule Xaas.ResearchRuntime.FondRecovery do
  @moduledoc false
  def recover(edges, failed) when is_list(edges), do: {:ok, Enum.reject(edges, &(&1 == failed))}
  def recover(edges, failed), do: {:refused, :boundary_violation}
end
