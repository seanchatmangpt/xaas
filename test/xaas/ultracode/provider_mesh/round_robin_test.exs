defmodule Xaas.Ultracode.ProviderMesh.RoundRobinTest do
  use ExUnit.Case, async: true
  alias Xaas.Ultracode.ProviderMesh.RoundRobin

  test "advances cursor" do
    assert {:a, 1} = RoundRobin.select([:a, :b], 0)
    assert {:b, 2} = RoundRobin.select([:a, :b], 1)
  end
end
