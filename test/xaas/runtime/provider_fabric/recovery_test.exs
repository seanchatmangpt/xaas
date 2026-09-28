defmodule Xaas.Runtime.ProviderFabric.RecoveryTest do
  use ExUnit.Case, async: true
  test "recovery runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Recovery)
  end
end
