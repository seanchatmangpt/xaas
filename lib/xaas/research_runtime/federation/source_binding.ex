defmodule Xaas.ResearchRuntime.SourceBinding do
  @moduledoc false
  @enforce_keys [:source_sha]
  defstruct [:source_sha, status: :unknown, provenance: %{}]
  def new(attrs) when is_list(attrs) do
    value = struct(__MODULE__, attrs)
    if Map.get(value, :source_sha) in [nil, ""], do: {:error, :missing_source_sha}, else: {:ok, value}
  end
  def admit(%__MODULE__{} = value, pred) when is_function(pred, 1),
    do: if(pred.(value), do: {:ok, %{value | status: :admitted}}, else: {:error, :refused})
end
