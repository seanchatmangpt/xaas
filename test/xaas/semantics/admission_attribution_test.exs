defmodule Xaas.Semantics.AdmissionAttributionTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.AdmissionAttribution

  @epsilon 1.0e-9

  defp pass(name), do: {name, fn _intent -> :pass end}
  defp refuse(name, reason \\ :denied), do: {name, fn _intent -> {:refuse, reason} end}

  # v(N) - v(empty) for a fixed intent/checks: +0.0 when all pass, -1.0 otherwise.
  defp efficiency_delta(checks) do
    all_pass = Enum.all?(checks, fn {_name, fun} -> fun.(:intent) == :pass end)
    if all_pass, do: 0.0, else: -1.0
  end

  describe "shapley/2 — Definition 5.2 exact attribution over the discrete check lattice" do
    test "3-check intent where check 2 refuses: phi concentrates on check 2" do
      checks = [pass(:policy_grounding), refuse(:provenance_complete), pass(:risk_classified)]

      assert %{:policy_grounding => a, :provenance_complete => b, :risk_classified => c} =
               AdmissionAttribution.shapley(:intent, checks)

      assert_in_delta b, -1.0, @epsilon
      assert a == 0.0
      assert c == 0.0
    end

    test "all checks pass: uniform attribution (every phi is exactly 0)" do
      checks = [pass(:a), pass(:b), pass(:c)]

      assert AdmissionAttribution.shapley(:intent, checks) ==
               %{:a => 0.0, :b => 0.0, :c => 0.0}
    end

    test "two of four checks refuse: blame splits equally (-0.5 each)" do
      checks = [pass(:a), refuse(:b), refuse(:c), pass(:d)]

      assert phi = AdmissionAttribution.shapley(:intent, checks)

      assert_in_delta phi.b, -0.5, @epsilon
      assert_in_delta phi.c, -0.5, @epsilon
      assert phi.a == 0.0
      assert phi.d == 0.0
    end

    test "efficiency axiom: sum(phi) == v(N) - v(empty) within 1e-9 across fixtures" do
      fixtures = [
        [pass(:only)],
        [refuse(:only)],
        [pass(:a), pass(:b), pass(:c)],
        [pass(:a), refuse(:b), pass(:c)],
        [pass(:a), refuse(:b), refuse(:c), pass(:d)],
        [refuse(:a), refuse(:b), refuse(:c)],
        Enum.map(1..8, fn i -> if rem(i, 3) == 0, do: refuse(:"c#{i}"), else: pass(:"c#{i}") end)
      ]

      for checks <- fixtures do
        assert phi = AdmissionAttribution.shapley(:intent, checks)
        delta = efficiency_delta(checks)
        assert abs(Enum.sum(Map.values(phi)) - delta) <= @epsilon
      end
    end

    test "n > 20: typed refusal :COALITION_LIMIT" do
      checks = Enum.map(1..21, &pass(:"c#{&1}"))
      assert AdmissionAttribution.shapley(:intent, checks) == {:error, :COALITION_LIMIT}
    end

    test "n == 20 is exactly at the 2^n bound and still admitted for computation" do
      checks = Enum.map(1..20, &pass(:"c#{&1}"))
      refute match?({:error, :COALITION_LIMIT}, AdmissionAttribution.shapley(:intent, checks))
    end

    test "determinism: identical inputs give identical attribution, exactly" do
      checks = [pass(:a), refuse(:b, :unrepresentable), pass(:c), pass(:d)]
      first = AdmissionAttribution.shapley(:intent, checks)

      for _ <- 1..5 do
        assert AdmissionAttribution.shapley(:intent, checks) == first
      end
    end

    test "malformed check verdict fails closed" do
      assert_raise ArgumentError, ~r/expected :pass \| \{:refuse, atom\}/, fn ->
        AdmissionAttribution.shapley(:intent, [{"bad", fn _ -> :ok end}])
      end
    end
  end
end
