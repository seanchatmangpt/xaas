defmodule Xaas.Runtime.ProviderFabric.EdgeTest do
  use ExUnit.Case, async: true

  test "edge runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Edge)
  end
end
