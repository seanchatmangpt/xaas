defmodule Xaas.ResearchRuntime.TrimtabWaveTest do
  @moduledoc false
  def case(role, expected) when role == expected, do: {:ok, :context_only}
  def case(role, expected), do: {:refused, :boundary_violation}
end
