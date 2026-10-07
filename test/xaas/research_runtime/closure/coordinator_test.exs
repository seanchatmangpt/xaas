defmodule Xaas.ResearchRuntime.CoordinatorTest do
  @moduledoc """
  Chicago court for `Xaas.ResearchRuntime.Coordinator` — the class representative of
  the 19-template research_runtime struct family (key-field gate + admit/2 predicate
  transition). Asserts on real struct state, no mocks: the collaborator is the module
  itself.
  """

  use ExUnit.Case, async: true

  alias Xaas.ResearchRuntime.Coordinator

  describe "new/1 key-field gate" do
    test "accepts a run_id and defaults status to :unknown" do
      assert {:ok, %Coordinator{} = c} = Coordinator.new(run_id: "run-1")
      assert c.run_id == "run-1"
      assert c.status == :unknown
      assert c.provenance == %{}
    end

    test "refuses a nil or blank run_id with a typed error" do
      assert {:error, :missing_run_id} = Coordinator.new(run_id: nil)
      assert {:error, :missing_run_id} = Coordinator.new(run_id: "")
      assert {:error, :missing_run_id} = Coordinator.new([])
    end
  end

  describe "admit/2 admission transition" do
    test "admitted predicate flips status to :admitted and preserves fields" do
      {:ok, c} = Coordinator.new(run_id: "run-2", provenance: %{sha: "abc"})
      assert {:ok, %Coordinator{status: :admitted} = admitted} =
               Coordinator.admit(c, &is_binary(&1.run_id))

      assert admitted.run_id == "run-2"
      assert admitted.provenance == %{sha: "abc"}
    end

    test "failing predicate returns typed :refused and leaves the original untouched" do
      {:ok, c} = Coordinator.new(run_id: "run-3")

      assert {:error, :refused} = Coordinator.admit(c, fn v -> v.status == :admitted end)
      assert %Coordinator{status: :unknown} = c
    end
  end

  test "admit/2 is not reachable for non-coordinator structs" do
    {:ok, c} = Coordinator.new(run_id: "run-4")
    other = %Xaas.ResearchRuntime.Replay{receipt_id: "r", status: :unknown, provenance: %{}}

    assert_raise FunctionClauseError, fn ->
      Coordinator.admit(other, fn _ -> true end)
    end
  end
end
