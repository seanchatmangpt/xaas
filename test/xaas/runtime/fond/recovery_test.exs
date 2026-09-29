defmodule Xaas.Runtime.FOND.RecoveryTest do
  use ExUnit.Case, async: true

  test "recovery test" do
    assert Xaas.Runtime.FOND.Recovery.route({:rate_limit, 429}) == :exclude_edge
    assert Xaas.Runtime.FOND.Recovery.route({:local, :bad}) == :repair_local
  end
end
