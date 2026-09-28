defmodule Xaas.ResearchRuntime.PlannerBinding do
  @moduledoc false
  def bind(intent, planner) when intent != nil and planner != nil, do: {:ok, %{intent: intent, planner: planner, authority: :none}}
  def bind(intent, planner), do: {:refused, :boundary_violation}
end
