defmodule Xaas.ResearchRuntime.EvolutionWaveTest do
  @moduledoc false
  def case(control, candidate) when candidate != control, do: {:ok, :paired_worlds_distinguishable}
  def case(control, candidate), do: {:refused, :boundary_violation}
end
