defmodule Xaas.ResearchRuntime.CommandTopology do
  @moduledoc false
  @enforce_keys [:command_id]
  defstruct [:command_id, status: :unknown, provenance: %{}]
  def new(attrs) when is_list(attrs) do
    value = struct(__MODULE__, attrs)
    if Map.get(value, :command_id) in [nil, ""], do: {:error, :missing_command_id}, else: {:ok, value}
  end
  def admit(%__MODULE__{} = value, pred) when is_function(pred, 1),
    do: if(pred.(value), do: {:ok, %{value | status: :admitted}}, else: {:error, :refused})
end
