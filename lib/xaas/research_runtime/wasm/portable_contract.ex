defmodule Xaas.ResearchRuntime.PortableContract do
  @moduledoc false
  @enforce_keys [:component_id]
  defstruct [:component_id, status: :unknown, provenance: %{}]
  def new(attrs) when is_list(attrs) do
    value = struct(__MODULE__, attrs)
    if Map.get(value, :component_id) in [nil, ""], do: {:error, :missing_component_id}, else: {:ok, value}
  end
  def admit(%__MODULE__{} = value, pred) when is_function(pred, 1),
    do: if(pred.(value), do: {:ok, %{value | status: :admitted}}, else: {:error, :refused})
end
