defmodule Xaas.Runtime.ProviderFabric.HealthTest do
  use ExUnit.Case, async: true

  test "health runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Health)
  end
end
