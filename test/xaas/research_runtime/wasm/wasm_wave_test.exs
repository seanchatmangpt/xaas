defmodule Xaas.ResearchRuntime.WasmWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.PortableContract

  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_component_id} = PortableContract.new([])
    assert {:ok, value} = PortableContract.new(component_id: "exact")
    assert {:error, :refused} = PortableContract.admit(value, fn _ -> false end)
    assert {:ok, admitted} = PortableContract.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
