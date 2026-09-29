defmodule Xaas.Runtime.FOND.TransitionTest do
  use ExUnit.Case, async: true

  test "transition test" do
    s = Xaas.Runtime.FOND.State.new(Xaas.Runtime.FOND.Graph.new())
    s2 = Xaas.Runtime.FOND.Transition.apply(s, {:attempted, :x})
    assert s2.attempts == 1
    assert Xaas.Runtime.FOND.Trace.replay(s2.trace) == [:x]
  end
end
