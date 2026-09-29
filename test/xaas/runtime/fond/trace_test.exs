defmodule Xaas.Runtime.FOND.TraceTest do
  use ExUnit.Case, async: true

  test "trace test" do
    t =
      %Xaas.Runtime.FOND.Trace{}
      |> Xaas.Runtime.FOND.Trace.add(:a)
      |> Xaas.Runtime.FOND.Trace.add(:b)

    assert Xaas.Runtime.FOND.Trace.replay(t) == [:a, :b]
  end
end
