defmodule Xaas.Planning.ProblemFeaturesTest do
  use ExUnit.Case, async: true

  alias Xaas.Planning.ProblemFeatures

  @all_false %{
    deterministic?: false,
    hierarchical?: false,
    nondeterministic?: false,
    stochastic?: false,
    partially_observed?: false,
    constraint_heavy?: false,
    optimization?: false,
    empirical_causal?: false
  }

  test "new/1 admits a complete boolean map" do
    assert {:ok, %ProblemFeatures{deterministic?: true}} =
             ProblemFeatures.new(%{@all_false | deterministic?: true})
  end

  test "new/1 admits a keyword list too" do
    attrs = Map.to_list(%{@all_false | optimization?: true})
    assert {:ok, %ProblemFeatures{optimization?: true}} = ProblemFeatures.new(attrs)
  end

  test "new/1 refuses a missing axis with a typed error naming it" do
    attrs = Map.delete(@all_false, :stochastic?)

    assert {:error, {:invalid_problem_features, {:missing_axes, [:stochastic?]}}} =
             ProblemFeatures.new(attrs)
  end

  test "new/1 refuses a non-boolean axis with a typed error naming it" do
    attrs = Map.put(@all_false, :hierarchical?, "yes")

    assert {:error, {:invalid_problem_features, {:non_boolean_axes, [:hierarchical?]}}} =
             ProblemFeatures.new(attrs)
  end

  test "axes/0 lists exactly the eight ticket-scoped classification axes" do
    assert Enum.sort(ProblemFeatures.axes()) ==
             Enum.sort([
               :deterministic?,
               :hierarchical?,
               :nondeterministic?,
               :stochastic?,
               :partially_observed?,
               :constraint_heavy?,
               :optimization?,
               :empirical_causal?
             ])
  end
end
