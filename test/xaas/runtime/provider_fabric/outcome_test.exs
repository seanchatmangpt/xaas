defmodule Xaas.Runtime.ProviderFabric.OutcomeTest do
  use ExUnit.Case, async: true
  test "outcome runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Outcome)
  end
end
