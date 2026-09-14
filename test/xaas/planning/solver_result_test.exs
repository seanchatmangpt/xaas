defmodule Xaas.Planning.SolverResultTest do
  use ExUnit.Case, async: true

  alias Xaas.Planning.SolverResult

  test "new/4 admits a well-formed normalized result" do
    assert {:ok, %SolverResult{formalism: :pddl, status: :solved, explanation: "ok", plan: [1]}} =
             SolverResult.new(:pddl, :solved, "ok", [1])
  end

  test "new/3 defaults plan to nil" do
    assert {:ok, %SolverResult{plan: nil}} = SolverResult.new(:hddl_htn, :unsolvable, "no plan")
  end

  test "new/4 refuses an unknown formalism" do
    assert {:error, {:invalid_solver_result, {:unknown_formalism, :not_a_formalism}}} =
             SolverResult.new(:not_a_formalism, :solved, "ok")
  end

  test "new/4 refuses an unknown status" do
    assert {:error, {:invalid_solver_result, {:unknown_status, :maybe}}} =
             SolverResult.new(:pddl, :maybe, "ok")
  end

  test "new/4 refuses a non-binary explanation" do
    assert {:error, {:invalid_solver_result, {:non_binary_explanation, :oops}}} =
             SolverResult.new(:pddl, :solved, :oops)
  end
end
