defmodule Xaas.Runtime.ProviderFabric.GraphTest do
  use ExUnit.Case, async: true
  test "graph runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Graph)
  end
end
