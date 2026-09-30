defmodule XaaS.Trimtab.ProviderSetTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.ProviderSet

  test "selection ignores excluded provider" do
    ps = [%{id: :a, capability: :plan}, %{id: :b, capability: :plan}]
    assert %{id: :b} = ProviderSet.select(ps, :plan, [:a])
  end
end
