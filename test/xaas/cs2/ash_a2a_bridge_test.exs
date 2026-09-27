defmodule XaaS.CS2.AshA2ABridgeTest do
  use ExUnit.Case, async: true
  alias XaaS.CS2.AshA2ABridge
  @packet %{subject: "https://chatman.ai/cs2#RFC-CS2-001", authority_ceiling: "CONSTRUCT",
    consumer: "https://chatman.ai/cs2#ash-a2a", work_id: "CS2-WRK-012", evidence: [], triage: %{}}

  test "projects admitted packet" do
    assert {:ok, workflow} = AshA2ABridge.ingest(@packet)
    assert workflow.work_id == "CS2-WRK-013"
    assert workflow.source.work_id == "CS2-WRK-012"
  end

  test "refuses divergent subject" do
    assert {:error, :fleet_contract_mismatch} =
      @packet |> Map.put(:subject, "https://chatman.ai/cs2#OTHER") |> AshA2ABridge.ingest()
  end
end
