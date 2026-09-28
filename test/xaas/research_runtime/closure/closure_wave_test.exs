defmodule Xaas.ResearchRuntime.ClosureWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.ExecutionEnvelope

  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_run_id} = ExecutionEnvelope.new([])
    assert {:ok, value} = ExecutionEnvelope.new(run_id: "exact")
    assert {:error, :refused} = ExecutionEnvelope.admit(value, fn _ -> false end)
    assert {:ok, admitted} = ExecutionEnvelope.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
