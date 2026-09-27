defmodule Xaas.CS2.AshA2ABridgeTest do
  use ExUnit.Case, async: true

  alias Xaas.CS2.AshA2ABridge

  test "projects bounded AshA2A packet without creating consequence" do
    packet = %{
      subject: "RFC-CS2-001",
      work_id: "CS2-WRK-012",
      consumer: "ash_a2a",
      evidence: [%{kind: "candidate", id: "ev-1"}],
      provenance: %{producer: "ggen-marketplace"},
      triage: %{priority: "P1"}
    }

    assert {:ok, projected} = AshA2ABridge.ingest(packet)
    assert projected.target_consumer == "xaas"
    assert projected.consequence == :none
    assert projected.selected_action == nil
  end

  test "refuses cross-subject packet" do
    assert {:error, {:contract_mismatch, _}} =
             AshA2ABridge.ingest(%{subject: "RFC-CS2-OTHER", work_id: "CS2-WRK-012"})
  end
end
