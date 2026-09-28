defmodule Xaas.ResearchRuntime.Substitution do
  @moduledoc false
  def equivalent(left, right) when left.consequence == right.consequence, do: {:ok, {left.id, right.id}}
  def equivalent(left, right), do: {:refused, :boundary_violation}
end
