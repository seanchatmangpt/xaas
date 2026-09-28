defmodule Xaas.ResearchRuntime.GraphWaveTest do
  @moduledoc false
  def case(before, after) when before == after, do: {:ok, :invariant_preserved}
  def case(before, after), do: {:refused, :boundary_violation}
end
