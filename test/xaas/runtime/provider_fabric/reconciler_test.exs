defmodule Xaas.Runtime.ProviderFabric.ReconcilerTest do
  use ExUnit.Case, async: true

  test "reconciler runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Reconciler)
  end
end
