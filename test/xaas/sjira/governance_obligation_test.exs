defmodule Xaas.Sjira.GovernanceObligationTest do
  use ExUnit.Case, async: true

  alias Xaas.Sjira.GovernanceObligation

  defp finding(id, disposition \\ "REWORK") do
    %{
      "id" => id,
      "required_action" => "REMEDIATE_#{id}",
      "action_owner" => "Platform Team",
      "evidence_required" => "evidence:#{id}",
      "disposition" => disposition
    }
  end

  defp gate_result(findings \\ [finding("G-001")]) do
    %{
      "gate" => "security",
      "phase" => "design",
      "findings" => findings
    }
  end

  defp obligation!() do
    {:ok, [obligation]} =
      GovernanceObligation.compile_gate(
        gate_result(),
        subject_ref: "sjira:work-order:42"
      )

    obligation
  end

  test "gate finding compiles into a powerless proposed obligation" do
    obligation = obligation!()

    assert obligation.standing == :proposed
    assert obligation.authority_ref == nil
    assert obligation.prepared_receipt_ref == nil
    refute obligation.ready_for_do
    assert byte_size(obligation.digest) == 64

    work = GovernanceObligation.work_item(obligation)
    assert work["classification"] == "GovernanceObligation"
    assert work["standing"] == "PROPOSED"
    assert work["authority_ref"] == nil
    assert work["prepared_receipt_ref"] == nil
    refute work["ready_for_do"]
  end

  test "admission does not imply authority" do
    obligation = obligation!()
    assert {:ok, admitted} = GovernanceObligation.admit(obligation, "sha256:admission")

    assert admitted.standing == :admitted
    assert admitted.admission_digest == "sha256:admission"
    assert admitted.authority_ref == nil
    assert admitted.prepared_receipt_ref == nil
    refute admitted.ready_for_do
    refute admitted.digest == obligation.digest
  end

  test "authority does not imply prepared consequence" do
    obligation = obligation!()
    {:ok, admitted} = GovernanceObligation.admit(obligation, "sha256:admission")
    assert {:ok, authorized} = GovernanceObligation.authorize(admitted, "odrl:permission:17")

    assert authorized.standing == :authorized
    assert authorized.authority_ref == "odrl:permission:17"
    assert authorized.prepared_receipt_ref == nil
    refute authorized.ready_for_do
  end

  test "only admitted then authorized then prepared becomes ready for do" do
    obligation = obligation!()
    {:ok, admitted} = GovernanceObligation.admit(obligation, "sha256:admission")
    {:ok, authorized} = GovernanceObligation.authorize(admitted, "odrl:permission:17")
    assert {:ok, prepared} =
             GovernanceObligation.prepare(authorized, "receipt:prepared:abc")

    assert prepared.standing == :prepared
    assert prepared.authority_ref == "odrl:permission:17"
    assert prepared.prepared_receipt_ref == "receipt:prepared:abc"
    assert prepared.ready_for_do
  end

  test "cannot skip admission or authority transitions" do
    proposed = obligation!()

    assert {:refused, refusal} =
             GovernanceObligation.authorize(proposed, "odrl:permission:17")

    assert refusal["reason"] == "AUTHORITY_TRANSITION_REFUSED"

    {:ok, admitted} = GovernanceObligation.admit(proposed, "sha256:admission")

    assert {:refused, refusal} =
             GovernanceObligation.prepare(admitted, "receipt:prepared:abc")

    assert refusal["reason"] == "PREPARED_RECEIPT_TRANSITION_REFUSED"
  end

  test "replay accepts exact obligation and refuses digest tamper" do
    obligation = obligation!()
    assert {:ok, ^obligation} = GovernanceObligation.replay(obligation)

    tampered = %{obligation | digest: String.duplicate("0", 64)}
    assert {:refused, refusal} = GovernanceObligation.replay(tampered)
    assert refusal["reason"] == "OBLIGATION_DIGEST_MISMATCH"
  end

  test "multiple findings compile in deterministic source order" do
    result =
      gate_result([
        finding("G-001"),
        finding("G-002", "SUSPENSION"),
        finding("G-003", "NO_GO")
      ])

    assert {:ok, obligations} =
             GovernanceObligation.compile_gate(
               result,
               subject_ref: "sjira:work-order:42"
             )

    assert Enum.map(obligations, & &1.finding_id) == ["G-001", "G-002", "G-003"]
    assert obligations |> Enum.map(& &1.digest) |> Enum.uniq() |> length() == 3
  end

  test "atom-keyed gate results are accepted without dynamic atom creation" do
    result = %{
      gate: "legal",
      phase: "design",
      findings: [
        %{
          id: "LEGAL-001",
          required_action: "EXECUTE_DPA",
          action_owner: "Legal",
          evidence_required: "DPA",
          disposition: "REWORK"
        }
      ]
    }

    assert {:ok, [obligation]} =
             GovernanceObligation.compile_gate(
               result,
               subject_ref: "sjira:work-order:99"
             )

    assert obligation.gate == "legal"
    assert obligation.finding_id == "LEGAL-001"
  end

  test "malformed finding refuses instead of manufacturing missing fields" do
    result = gate_result([%{"id" => "BROKEN"}])

    assert {:refused, refusal} =
             GovernanceObligation.compile_gate(
               result,
               subject_ref: "sjira:work-order:42"
             )

    assert refusal["reason"] == "MALFORMED_FINDING"
    assert "required_action" in refusal["detail"].missing
    assert "action_owner" in refusal["detail"].missing
  end

  test "OCEL projection records transition without granting authority" do
    obligation = obligation!()
    at = ~U[2026-09-26 05:30:00Z]
    event = GovernanceObligation.ocel_event(obligation, :proposed, at)

    assert event["type"] == "sjira.governance.proposed"
    assert event["time"] == DateTime.to_iso8601(at)
    assert event["attributes"]["standing"] == "PROPOSED"
    assert event["attributes"]["authority_ref"] == nil
    refute event["attributes"]["ready_for_do"]
    assert event["relationships"] == [
             %{"objectId" => "sjira:work-order:42", "qualifier" => "governs"},
             %{
               "objectId" => obligation.obligation_id,
               "qualifier" => "obligation"
             }
           ]
  end

  test "OCEL fragment is directly shaped for Xaas.Ocel.Projection import" do
    obligation = obligation!()
    at = ~U[2026-09-26 05:30:00Z]
    fragment = GovernanceObligation.ocel_fragment(obligation, :proposed, at)

    assert fragment["objectTypes"] == [
             "governance_obligation",
             "sjira_work_order"
           ]

    assert fragment["eventTypes"] == ["sjira.governance.proposed"]
    assert Enum.map(fragment["objects"], & &1["id"]) == [
             "sjira:work-order:42",
             obligation.obligation_id
           ]

    assert [event] = fragment["events"]
    assert event == GovernanceObligation.ocel_event(obligation, :proposed, at)
  end
end
