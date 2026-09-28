defmodule Xaas.Runtime.ProviderFabric.LeaseTest do
  use ExUnit.Case, async: true
  test "lease runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Lease)
  end
end
