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

    assert {:ok, projected} = AshA2ABridge.from_a2a(packet)
    assert projected["kind"] == "cs2.engineer_workflow"
    assert projected["authority"] == "NONE"
    assert projected["subject"] == "https://chatman.ai/cs2#RFC-CS2-001"
    assert projected["evidence"]["work_id"] == "CS2-WRK-012"
  end

  test "refuses cross-subject packet" do
    assert {:error, {:unsupported_cs2_subject, "RFC-CS2-OTHER"}} =
             AshA2ABridge.from_a2a(%{subject: "RFC-CS2-OTHER", work_id: "CS2-WRK-012"})
  end
end
