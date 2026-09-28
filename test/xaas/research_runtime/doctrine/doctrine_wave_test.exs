defmodule Xaas.ResearchRuntime.DoctrineWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.Intent
  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_intent_id} = Intent.new([])
    assert {:ok, value} = Intent.new(intent_id: "exact")
    assert {:error, :refused} = Intent.admit(value, fn _ -> false end)
    assert {:ok, admitted} = Intent.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
