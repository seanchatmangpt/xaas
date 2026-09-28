defmodule Xaas.ResearchRuntime.ModelRole do
  @moduledoc false
  def new(model, context) when model != nil, do: {:ok, %{model: model, context: context, construct: false, select: false, do: false}}
  def new(model, context), do: {:refused, :boundary_violation}
end
