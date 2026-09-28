defmodule Xaas.ResearchRuntime.EvidenceWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.EvidenceAdmission
  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_evidence_id} = EvidenceAdmission.new([])
    assert {:ok, value} = EvidenceAdmission.new(evidence_id: "exact")
    assert {:error, :refused} = EvidenceAdmission.admit(value, fn _ -> false end)
    assert {:ok, admitted} = EvidenceAdmission.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
