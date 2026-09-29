defmodule Xaas.ResearchRuntime.GraphWaveTest do
  @moduledoc false
  def case(before_state, after_state) when before_state == after_state,
    do: {:ok, :invariant_preserved}

  def case(_before_state, _after_state), do: {:refused, :boundary_violation}
end
