defmodule Xaas.Trimtab.ProviderSetTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.{Provider, ProviderSet}

  test "selection ignores excluded provider" do
    ps = [Provider.new(:a, Fake, [:plan], 1), Provider.new(:b, Fake, [:plan], 2)]
    assert ProviderSet.select(ps, :plan) == Enum.at(ps, 0)
    assert ProviderSet.select(ps, :plan, MapSet.new([:a])) == Enum.at(ps, 1)
    assert ProviderSet.candidates(ps, :plan) |> length() == 2
    assert ProviderSet.select(ps, :other) == nil
  end
end
