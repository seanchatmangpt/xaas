defmodule Xaas.Planning.RegimeRouterStepTest do
  @moduledoc """
  Real `Reactor.run/2` coverage for `Xaas.Planning.RegimeRouterStep` -- the
  ticket's "wired into the existing Ash/Reactor boundary" requirement
  (`docs/jira/v26.9.11/planning-regime-router.md`). Builds a real tiny
  Reactor at compile time and runs it for real; no Reactor/step mocking.
  """
  use ExUnit.Case, async: true

  defmodule TestReactor do
    use Reactor

    input(:features)
    input(:problem)

    step :route, Xaas.Planning.RegimeRouterStep do
      argument(:features, input(:features))
      argument(:problem, input(:problem))
    end

    return(:route)
  end

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

  # Reactor.run/2 does not hand back a failed step's own {:error, reason}
  # verbatim -- it wraps every step failure in a real
  # `Reactor.Error.Invalid` (with the step's actual error nested in one of
  # its `errors` entries' `.error` field). These tests assert on that real
  # wrapped shape, not on a re-derived/idealized one.
  defp unwrap_step_error(%Reactor.Error.Invalid{errors: [%{error: error} | _]}), do: error

  test "a real Reactor run admits a raw feature map and returns the typed unsupported error" do
    features = Map.put(@all_false, :deterministic?, true)

    assert {:error, invalid} = Reactor.run(TestReactor, %{features: features, problem: %{}})
    assert {:unsupported, :pddl, reason} = unwrap_step_error(invalid)
    assert is_binary(reason)
  end

  test "a real Reactor run refuses malformed features via the typed admission error" do
    bad_features = Map.put(@all_false, :hierarchical?, "not a boolean")

    assert {:error, invalid} = Reactor.run(TestReactor, %{features: bad_features, problem: %{}})

    assert {:invalid_problem_features, {:non_boolean_axes, [:hierarchical?]}} =
             unwrap_step_error(invalid)
  end

  test "a real Reactor run accepts an already-admitted ProblemFeatures struct" do
    {:ok, features} =
      Xaas.Planning.ProblemFeatures.new(Map.put(@all_false, :constraint_heavy?, true))

    assert {:error, invalid} = Reactor.run(TestReactor, %{features: features, problem: %{}})
    assert {:unsupported, :sat_smt_cp, _reason} = unwrap_step_error(invalid)
  end
end
