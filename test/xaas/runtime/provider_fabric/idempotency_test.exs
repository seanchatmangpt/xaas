defmodule Xaas.Runtime.ProviderFabric.IdempotencyTest do
  use ExUnit.Case, async: true

  test "idempotency runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Idempotency)
  end
end
