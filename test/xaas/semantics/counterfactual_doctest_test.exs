defmodule Xaas.Semantics.CounterfactualDocTest do
  @moduledoc """
  Lane W880 — doctest harness for `Xaas.Semantics.Counterfactual.run/2`.

  Runs the `iex>` examples in the `@doc` of
  `Xaas.Semantics.Counterfactual.run/2` as real assertions: the expected
  outcomes and per-check verdict logs were derived by actually running the
  function (not guessed), and this suite re-runs them on every test pass so
  the docs cannot drift from the pipeline.
  """

  use ExUnit.Case, async: true

  doctest Xaas.Semantics.Counterfactual

  # W907 regression: a bare 1-arity fun check must be accepted per the
  # `@typedoc check` contract. Pre-fix, normalize_check/1 passed
  # Function.info(fun, :name) — a {:name, atom} *tuple* — into
  # normalize_name/1, which only matches atoms/binaries, raising
  # FunctionClauseError. Mutation rationale: reverting the
  # normalize_check/1 bare-fun clause to its pre-fix body makes this test
  # raise FunctionClauseError (witnessed on the exact subject).
  test "bare anonymous fun check is supported and deterministically named" do
    assert %{outcome: :admitted, checks: [%{name: :check, verdict: :pass, refusal: nil}]} =
             Xaas.Semantics.Counterfactual.run("raw", [fn _ -> :ok end])

    assert %{outcome: {:refused, :too_raw}, checks: [%{name: :check, verdict: :fail}]} =
             Xaas.Semantics.Counterfactual.run("raw", [fn _ -> {:refused, :too_raw} end])
  end
end
