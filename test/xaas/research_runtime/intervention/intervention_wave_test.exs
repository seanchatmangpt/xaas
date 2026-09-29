defmodule Xaas.ResearchRuntime.InterventionWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.WorkOrder

  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_work_order_iri} = WorkOrder.new([])
    assert {:ok, value} = WorkOrder.new(work_order_iri: "exact")
    assert {:error, :refused} = WorkOrder.admit(value, fn _ -> false end)
    assert {:ok, admitted} = WorkOrder.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
