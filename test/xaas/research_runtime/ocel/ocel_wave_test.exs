defmodule Xaas.ResearchRuntime.OcelWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.Event

  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_event_id} = Event.new([])
    assert {:ok, value} = Event.new(event_id: "exact")
    assert {:error, :refused} = Event.admit(value, fn _ -> false end)
    assert {:ok, admitted} = Event.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
