defmodule Xaas.Planning.RegimeRouterTest do
  @moduledoc """
  Real, Chicago-style coverage for `Xaas.Planning.RegimeRouter` -- real
  `Xaas.Planning.ProblemFeatures` structs, the real (empty)
  `Xaas.Planning.AdapterRegistry`, and a real ad hoc `Reactor.run/2` against
  `Xaas.Planning.RegimeRouterStep`. No mocking of the router, the registry,
  or Reactor.
  """
  use ExUnit.Case, async: true

  alias Xaas.Planning.{AdapterRegistry, Formalism, ProblemFeatures, RegimeRouter}

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

  defp features!(overrides) do
    {:ok, features} = ProblemFeatures.new(Map.merge(@all_false, overrides))
    features
  end

  describe "classify/1" do
    test "routes each single-axis feature set to its ticket-specified formalism" do
      assert {:ok, :pddl} = RegimeRouter.classify(features!(%{deterministic?: true}))
      assert {:ok, :hddl_htn} = RegimeRouter.classify(features!(%{hierarchical?: true}))
      assert {:ok, :fond} = RegimeRouter.classify(features!(%{nondeterministic?: true}))
      assert {:ok, :ppddl_mdp} = RegimeRouter.classify(features!(%{stochastic?: true}))
      assert {:ok, :pomdp} = RegimeRouter.classify(features!(%{partially_observed?: true}))
      assert {:ok, :sat_smt_cp} = RegimeRouter.classify(features!(%{constraint_heavy?: true}))
      assert {:ok, :lp_milp_qp} = RegimeRouter.classify(features!(%{optimization?: true}))
      assert {:ok, :scm_causal} = RegimeRouter.classify(features!(%{empirical_causal?: true}))
    end

    test "refuses an all-false feature set instead of defaulting to a formalism" do
      assert {:error, :no_admitted_formalism} = RegimeRouter.classify(features!(%{}))
    end

    test "resolves multiple admitted axes by the ticket's listed priority order" do
      features = features!(%{deterministic?: true, empirical_causal?: true})
      assert {:ok, :pddl} = RegimeRouter.classify(features)

      features = features!(%{hierarchical?: true, optimization?: true})
      assert {:ok, :hddl_htn} = RegimeRouter.classify(features)
    end
  end

  describe "dispatch/2 with the real (empty) adapter registry" do
    test "every currently-unimplemented formalism returns a typed :unsupported error, never a fabricated plan" do
      for formalism <- Formalism.all() do
        refute AdapterRegistry.capable?(formalism),
               "expected #{formalism} to have no real adapter registered in this slice"
      end

      features = features!(%{deterministic?: true})

      assert {:error, {:unsupported, :pddl, reason}} = RegimeRouter.dispatch(features, %{})
      assert is_binary(reason)
    end

    test "an unclassifiable problem is refused before the registry is even consulted" do
      assert {:error, :no_admitted_formalism} = RegimeRouter.dispatch(features!(%{}), %{})
    end
  end
end
