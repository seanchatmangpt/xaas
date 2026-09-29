defmodule Xaas.ResearchRuntime.TrimtabWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.ContextWindow

  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_context_id} = ContextWindow.new([])
    assert {:ok, value} = ContextWindow.new(context_id: "exact")
    assert {:error, :refused} = ContextWindow.admit(value, fn _ -> false end)
    assert {:ok, admitted} = ContextWindow.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
