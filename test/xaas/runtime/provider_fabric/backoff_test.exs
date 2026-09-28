defmodule Xaas.Runtime.ProviderFabric.BackoffTest do
  use ExUnit.Case, async: true
  test "backoff runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Backoff)
  end
end
