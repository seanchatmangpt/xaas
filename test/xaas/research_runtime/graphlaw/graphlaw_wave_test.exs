defmodule Xaas.ResearchRuntime.GraphlawWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.GraphInvariant
  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_graph_id} = GraphInvariant.new([])
    assert {:ok, value} = GraphInvariant.new(graph_id: "exact")
    assert {:error, :refused} = GraphInvariant.admit(value, fn _ -> false end)
    assert {:ok, admitted} = GraphInvariant.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
