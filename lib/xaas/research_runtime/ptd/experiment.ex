defmodule Xaas.ResearchRuntime.Experiment do
  @moduledoc false
  def measure(red_cost, buyer_value) when is_number(red_cost) and is_number(buyer_value), do: {:ok, %{red_team_cost: red_cost, buyer_value: buyer_value}}
  def measure(red_cost, buyer_value), do: {:refused, :boundary_violation}
end
