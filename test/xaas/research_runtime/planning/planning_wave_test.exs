defmodule Xaas.ResearchRuntime.PlanningWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.HddlTask

  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_task_id} = HddlTask.new([])
    assert {:ok, value} = HddlTask.new(task_id: "exact")
    assert {:error, :refused} = HddlTask.admit(value, fn _ -> false end)
    assert {:ok, admitted} = HddlTask.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
