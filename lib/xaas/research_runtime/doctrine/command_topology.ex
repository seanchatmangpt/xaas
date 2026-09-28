defmodule Xaas.ResearchRuntime.CommandTopology do
  @moduledoc false
  def route(binding, role) when binding != nil and role != nil, do: {:ok, %{binding: binding, role: role}}
  def route(binding, role), do: {:refused, :boundary_violation}
end
