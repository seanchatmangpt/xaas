defmodule Xaas.Runtime.ProviderFabric.SelectorTest do
  use ExUnit.Case, async: true

  test "selector runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Selector)
  end
end
