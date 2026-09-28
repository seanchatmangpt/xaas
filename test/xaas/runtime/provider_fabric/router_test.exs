defmodule Xaas.Runtime.ProviderFabric.RouterTest do
  use ExUnit.Case, async: true
  test "router runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Router)
  end
end
