defmodule Xaas.Runtime.ProviderFabric.QueueTest do
  use ExUnit.Case, async: true

  test "queue runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Queue)
  end
end
