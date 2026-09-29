defmodule Xaas.ResearchRuntime.ProviderAdapter do
  @moduledoc false
  @enforce_keys [:provider_id]
  defstruct [:provider_id, status: :unknown, provenance: %{}]

  def new(attrs) when is_list(attrs) do
    value = struct(__MODULE__, attrs)

    if Map.get(value, :provider_id) in [nil, ""],
      do: {:error, :missing_provider_id},
      else: {:ok, value}
  end

  def admit(%__MODULE__{} = value, pred) when is_function(pred, 1),
    do: if(pred.(value), do: {:ok, %{value | status: :admitted}}, else: {:error, :refused})
end
