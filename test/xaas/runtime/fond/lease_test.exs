defmodule Xaas.Runtime.FOND.LeaseTest do
  use ExUnit.Case, async: true

  test "lease test" do
    assert Xaas.Runtime.FOND.Lease.new(:k, self(), 1000) |> Xaas.Runtime.FOND.Lease.valid?()
  end
end
