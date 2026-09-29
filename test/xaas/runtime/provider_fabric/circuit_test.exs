defmodule Xaas.Runtime.ProviderFabric.CircuitTest do
  use ExUnit.Case, async: true

  test "circuit runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Circuit)
  end
end
