defmodule Xaas.Runtime.ProviderFabric.PlannerTest do
  use ExUnit.Case, async: true

  test "planner runtime surface is loadable" do
    assert Code.ensure_loaded?(Xaas.Runtime.ProviderFabric.Planner)
  end
end
