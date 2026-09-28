defmodule Xaas.ResearchRuntime.SemanticPart do
  @moduledoc false
  def bind(part, source) when part != nil and source != nil, do: {:ok, %{part: part, source: source}}
  def bind(part, source), do: {:refused, :boundary_violation}
end
