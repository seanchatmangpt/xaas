defmodule Xaas.Runtime.FOND.DeadlineTest do
  use ExUnit.Case, async: true

  test "deadline test" do
    d = Xaas.Runtime.FOND.Deadline.new(1000)
    assert Xaas.Runtime.FOND.Deadline.remaining(d) > 0
  end
end
