defmodule Xaas.Runtime.ProviderFabric.ProviderTest do
  use ExUnit.Case, async: true
  test "provider runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Provider)
  end
end
