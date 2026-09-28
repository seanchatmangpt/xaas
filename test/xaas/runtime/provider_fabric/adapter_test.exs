defmodule Xaas.Runtime.ProviderFabric.AdapterTest do
  use ExUnit.Case, async: true
  test "adapter runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Adapter)
  end
end
