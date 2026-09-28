defmodule Xaas.ResearchRuntime.WasmWaveTest do
  @moduledoc false
  def case(required, offered) when required -- offered == [], do: {:ok, :capabilities_satisfied}
  def case(required, offered), do: {:refused, :boundary_violation}
end
