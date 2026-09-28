defmodule Xaas.ResearchRuntime.InterchangeWaveTest do
  @moduledoc false
  def case(before, after) when before == after, do: {:ok, :consequence_preserved}
  def case(before, after), do: {:refused, :boundary_violation}
end
