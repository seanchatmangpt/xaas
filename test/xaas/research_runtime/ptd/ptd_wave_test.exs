defmodule Xaas.ResearchRuntime.PtdWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.Epoch
  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_epoch_id} = Epoch.new([])
    assert {:ok, value} = Epoch.new(epoch_id: "exact")
    assert {:error, :refused} = Epoch.admit(value, fn _ -> false end)
    assert {:ok, admitted} = Epoch.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
