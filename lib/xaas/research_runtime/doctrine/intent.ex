defmodule Xaas.ResearchRuntime.Intent do
  @moduledoc false
  def new(strategy, constraints) when strategy != nil and is_list(constraints), do: {:ok, %{strategy: strategy, constraints: constraints}}
  def new(strategy, constraints), do: {:refused, :boundary_violation}
end
