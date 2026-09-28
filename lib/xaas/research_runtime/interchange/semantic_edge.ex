defmodule Xaas.ResearchRuntime.SemanticEdge do
  @moduledoc false
  def new(id, consequence, provider) when id != nil and consequence != nil, do: {:ok, %{id: id, consequence: consequence, provider: provider, state: :eligible}}
  def new(id, consequence, provider), do: {:refused, :boundary_violation}
end
