defmodule Xaas.Runtime.ProviderFabric.PolicyTest do
  use ExUnit.Case, async: true

  test "policy runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Policy)
  end
end
