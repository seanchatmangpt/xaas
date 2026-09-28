defmodule Xaas.ResearchRuntime.InterchangeWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.SemanticEdge

  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_edge_id} = SemanticEdge.new([])
    assert {:ok, value} = SemanticEdge.new(edge_id: "exact")
    assert {:error, :refused} = SemanticEdge.admit(value, fn _ -> false end)
    assert {:ok, admitted} = SemanticEdge.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
