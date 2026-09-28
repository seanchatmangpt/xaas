defmodule Xaas.ResearchRuntime.EdgeSet do
  @moduledoc false
  def exclude(edges, failed_id) when is_list(edges), do: {:ok, Enum.reject(edges, &(&1.id == failed_id))}
  def exclude(edges, failed_id), do: {:refused, :boundary_violation}
end
