defmodule Xaas.ResearchRuntime.InterventionWaveTest do
  @moduledoc false
  def case(remaining, requested) when remaining >= requested, do: {:ok, :within_budget}
  def case(remaining, requested), do: {:refused, :boundary_violation}
end
