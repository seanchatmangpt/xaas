defmodule Xaas.ResearchRuntime.PtdWaveTest do
  @moduledoc false
  def case(before, after) when before != after, do: {:ok, :implementation_phased}
  def case(before, after), do: {:refused, :boundary_violation}
end
