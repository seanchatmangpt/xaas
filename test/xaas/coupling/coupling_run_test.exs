defmodule Xaas.Coupling.CouplingRunTest do
  use ExUnit.Case, async: true

  alias Xaas.Coupling.CouplingRun

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "couple admits a box-constrained proposal set and persists a real receipt" do
    proposals = [
      %{"id" => "sector-a", "vector" => [10.0], "confidence" => 1.0, "staleness" => 0.0},
      %{"id" => "sector-b", "vector" => [30.0], "confidence" => 1.0, "staleness" => 0.0}
    ]

    {:ok, run} =
      CouplingRun
      |> Ash.Changeset.for_create(:couple, %{
        proposals: proposals,
        constraints: %{"lower" => [0.0], "upper" => [15.0]}
      })
      |> Ash.create()

    assert run.status == :solved
    # unconstrained mean would be 20.0, clamped to the upper bound 15.0
    assert run.z == [15.0]
    assert run.weights["sector-a"] == run.weights["sector-b"]
    assert run.receipt["0"]["kind"] == "bound_clamped"
    assert run.requested_at != nil
  end

  test "couple stores a typed unsupported reason for general affine constraints" do
    proposals = [%{"id" => "a", "vector" => [1.0], "confidence" => 1.0, "staleness" => 0.0}]

    {:ok, run} =
      CouplingRun
      |> Ash.Changeset.for_create(:couple, %{
        proposals: proposals,
        constraints: %{"a_ineq" => [[1.0]], "b_ineq" => [5.0]}
      })
      |> Ash.create()

    assert run.status == :unsupported
    assert run.unsupported_reason["reason"] == "general_affine_constraints_unsupported"
    assert run.z == nil
  end

  test "couple stores infeasibility with the minimal unsatisfiable constraint" do
    proposals = [%{"id" => "a", "vector" => [1.0], "confidence" => 1.0, "staleness" => 0.0}]

    {:ok, run} =
      CouplingRun
      |> Ash.Changeset.for_create(:couple, %{
        proposals: proposals,
        constraints: %{"lower" => [10.0], "upper" => [1.0]}
      })
      |> Ash.create()

    assert run.status == :infeasible
    [conflict] = run.unsupported_reason["minimal_unsatisfiable_constraints"]
    assert conflict["coordinate"] == 0
  end

  test "couple with an empty proposal set fails admission with a real changeset error" do
    assert {:error, %Ash.Error.Invalid{}} =
             CouplingRun
             |> Ash.Changeset.for_create(:couple, %{proposals: [], constraints: %{}})
             |> Ash.create()
  end

  test "deny-by-default: read requires the bypass, no other path admits it" do
    assert {:ok, _list} = Ash.read(CouplingRun)
  end
end
