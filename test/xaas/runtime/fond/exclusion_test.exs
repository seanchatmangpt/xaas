defmodule Xaas.Runtime.FOND.ExclusionTest do
  use ExUnit.Case, async: true

  test "exclusion test" do
    e = Xaas.Runtime.FOND.Edge.new(:a, fn _ -> {:error, :down} end, capabilities: [:run])

    assert {:exhausted, [{:a, :down}], g} =
             Xaas.Runtime.FOND.Executor.run(Xaas.Runtime.FOND.Graph.new([e]), :run, :x)

    assert MapSet.member?(g.excluded, :a)
  end
end
