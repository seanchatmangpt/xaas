defmodule Xaas.ResearchRuntime.AuthorityFence do
  @moduledoc false
  def admit(capability, authority) when authority == :construct or authority == :execute, do: {:ok, %{capability: capability, authority: authority}}
  def admit(capability, authority), do: {:refused, :boundary_violation}
end
