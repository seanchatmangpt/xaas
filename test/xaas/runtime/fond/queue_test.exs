defmodule Xaas.Runtime.FOND.QueueTest do
  use ExUnit.Case, async: true

  test "queue test" do
    q = Xaas.Runtime.FOND.Queue.new() |> Xaas.Runtime.FOND.Queue.push(:x)
    assert {:ok, :x, _} = Xaas.Runtime.FOND.Queue.pop(q)
  end
end
