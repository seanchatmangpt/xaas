defmodule Xaas.ResearchRuntime.CommandBudget do
  @moduledoc false
  @enforce_keys [:budget]
  defstruct [:budget, status: :unknown, provenance: %{}]
  def new(attrs) when is_list(attrs) do
    value = struct(__MODULE__, attrs)
    if Map.get(value, :budget) in [nil, ""], do: {:error, :missing_budget}, else: {:ok, value}
  end
  def admit(%__MODULE__{} = value, pred) when is_function(pred, 1),
    do: if(pred.(value), do: {:ok, %{value | status: :admitted}}, else: {:error, :refused})
end
