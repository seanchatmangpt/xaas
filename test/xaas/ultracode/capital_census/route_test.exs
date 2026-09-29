defmodule Xaas.Ultracode.CapitalCensus.RouteTest do
  @moduledoc """
  Qualification of the route lattice (`Xaas.Ultracode.CapitalCensus.Route`,
  GC-26926-CENSUS):

    * the lattice is the directive's exact rung list and the order is
      total: every adjacent pair asserts both directions, plus the
      extreme pair and reflexivity;
    * unknown routes refuse typed (`{:refused, :unknown_route}`);
    * `select/2` picks the LOWEST applicable rung — a `:reuse` candidate
      beats `:generate` even out of input order (anti-vacuity: the
      lattice, not the candidate order, decides);
    * the residual reaches `:llm` ONLY when every lower rung is recorded
      failed; `:llm` itself unavailable refuses `{:refused, :no_route}` —
      `:llm` is the TOP of the lattice, never the default.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.CapitalCensus.Route

  # The directive's exact lattice: Reuse ≺ Compose ≺ Rule ≺ Plan ≺
  # Constraint ≺ Generate ≺ SpecializedModel ≺ LLM.
  @lattice [:reuse, :compose, :rule, :plan, :constraint, :generate, :specialized_model, :llm]

  describe "lattice order" do
    test "@lattice is the directive's exact rung list" do
      assert Route.lattice() == @lattice
    end

    test "every adjacent pair: lower beats higher in both directions" do
      @lattice
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [lower, higher] ->
        assert Route.compare(lower, higher) == :lt, "expected #{lower} ≺ #{higher}"
        assert Route.compare(higher, lower) == :gt, "expected #{higher} ≻ #{lower}"
      end)
    end

    test "the order is total: extreme pair, and every rung is :eq with itself" do
      assert Route.compare(:reuse, :llm) == :lt
      assert Route.compare(:llm, :reuse) == :gt

      for rung <- @lattice do
        assert Route.compare(rung, rung) == :eq
      end
    end

    test "rank is the 0-based position; unknown routes refuse typed" do
      @lattice
      |> Enum.with_index()
      |> Enum.each(fn {rung, position} ->
        assert Route.rank(rung) == {:ok, position}
      end)

      assert Route.rank(:telepathy) == {:refused, :unknown_route}
      assert Route.rank("reuse") == {:refused, :unknown_route}
    end

    test "compare is defined only on the lattice (rank/1 is the typed total function)" do
      assert_raise FunctionClauseError, fn ->
        Route.compare(:telepathy, :reuse)
      end
    end
  end

  describe "select/2" do
    test "anti-vacuity: :reuse beats :generate even out of input order" do
      assert Route.select([:generate, :reuse], %{}) == {:ok, :reuse}
      assert Route.select([:reuse, :generate], %{}) == {:ok, :reuse}
    end

    test "picks the lowest applicable among atoms and maps with :route keys" do
      candidates = [%{route: :plan}, :generate, %{route: :compose, applicable: true}]

      assert Route.select(candidates, %{}) == {:ok, :compose}
    end

    test "context :failed and candidate inapplicability remove rungs" do
      candidates = [%{route: :reuse, applicable: false}, :compose, :generate]

      assert Route.select(candidates, %{}) == {:ok, :compose}
      assert Route.select(candidates, %{failed: [:compose]}) == {:ok, :generate}
      assert Route.select(candidates, %{failed: [:compose, :generate]}) == {:refused, :no_route}
    end

    test "empty candidates and unknown routes refuse typed" do
      assert Route.select([], %{}) == {:refused, :no_route}
      assert Route.select([:telepathy], %{}) == {:refused, :unknown_route}
      assert Route.select([%{route: :telepathy}], %{}) == {:refused, :unknown_route}
    end
  end

  describe "residual_route/1" do
    test "the irreducible residual: every lower rung failed ⇒ :llm" do
      all_lower = @lattice -- [:llm]

      assert Route.residual_route(all_lower) == {:ok, :llm}
      # The order of the failure record is irrelevant.
      assert Route.residual_route(Enum.shuffle(all_lower)) == {:ok, :llm}
    end

    test "a still-applicable lower rung denies the residual to :llm" do
      assert Route.residual_route([]) == {:ok, :reuse}
      assert Route.residual_route([:reuse]) == {:ok, :compose}
      assert Route.residual_route([:compose, :generate]) == {:ok, :reuse}

      assert Route.residual_route([:reuse, :compose, :plan, :constraint, :generate]) ==
               {:ok, :rule}
    end

    test ":llm itself unavailable ⇒ {:refused, :no_route} (never a fallback)" do
      assert Route.residual_route(@lattice) == {:refused, :no_route}
      assert Route.residual_route([:llm]) == {:refused, :no_route}
    end

    test "unknown rungs refuse typed" do
      assert Route.residual_route([:telepathy]) == {:refused, :unknown_route}
    end
  end
end
