defmodule Xaas.Trimtab.RecoveryTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.{Failure, Recovery, Provider, ProviderSet}

  test "failed edge is excluded only" do
    ps = [Provider.new(:a, Fake, [:plan]), Provider.new(:b, Fake, [:plan])]
    assert Recovery.next(ps, :plan, []) == {:ok, Enum.at(ps, 0)}

    {:ok, f} = Failure.new(:a, :transient, :timeout)
    assert Recovery.next(ps, :plan, [f]) == {:ok, Enum.at(ps, 1)}

    fs = fs1 = [f, elem(Failure.new(:b, :transient, :timeout), 1)]
    assert Recovery.next(ps, :plan, fs) == {:error, :no_lawful_provider}
    assert Recovery.record(fs1, :b, :transient, :timeout) ==
             {:ok, fs1 ++ [struct(Failure, provider_id: :b, class: :transient, reason: :timeout)]}
  end
end
