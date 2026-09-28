defmodule Xaas.ResearchRuntime.Standing do
  @moduledoc false
  @enforce_keys [:subject_sha]
  defstruct [:subject_sha, status: :unknown, provenance: %{}]

  def new(attrs) when is_list(attrs) do
    value = struct(__MODULE__, attrs)

    if Map.get(value, :subject_sha) in [nil, ""],
      do: {:error, :missing_subject_sha},
      else: {:ok, value}
  end

  def admit(%__MODULE__{} = value, pred) when is_function(pred, 1),
    do: if(pred.(value), do: {:ok, %{value | status: :admitted}}, else: {:error, :refused})
end
