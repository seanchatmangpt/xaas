defmodule Xaas.Runtime.ProviderFabric.StateTest do
  use ExUnit.Case, async: true

  test "state runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.State)
  end
end
