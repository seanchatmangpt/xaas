defmodule Xaas.Sjira.GovernanceRouteTest do
  use ExUnit.Case, async: true

  alias Xaas.Sjira.{GovernanceObligation, GovernanceRoute}

  defp finding(id, disposition \\ "REWORK") do
    %{
      "id" => id,
      "required_action" => "ACTION_#{id}",
      "action_owner" => "Owner",
      "evidence_required" => "evidence:#{id}",
      "disposition" => disposition
    }
  end

  defp gate(gate, phase, findings) do
    %{"gate" => gate, "phase" => phase, "findings" => findings}
  end

  test "route compilation preserves gate/finding order and receipts the exact set" do
    results = [
      gate("security", "design", [finding("SEC-1"), finding("SEC-2")]),
      gate("legal", "design", [finding("LEGAL-1", "SUSPENSION")])
    ]

    assert {:ok, obligations, receipt} =
             GovernanceRoute.compile(results, subject_ref: "sjira:work-order:7")

    assert Enum.map(obligations, & &1.finding_id) == ["SEC-1", "SEC-2", "LEGAL-1"]
    assert receipt.subject_ref == "sjira:work-order:7"
    assert tuple_size(receipt.obligation_digests) == 3
    assert receipt.standing_counts == %{"proposed" => 3}
    assert receipt.disposition_counts == %{"REWORK" => 2, "SUSPENSION" => 1}
    assert receipt.ready_for_do_count == 0
    assert byte_size(receipt.digest) == 64
    assert {:ok, ^receipt} = GovernanceRoute.replay(obligations, receipt)
  end

  test "duplicate obligation identity is refused across repeated gate results" do
    duplicated = gate("security", "design", [finding("SEC-1")])

    assert {:refused, refusal} =
             GovernanceRoute.compile(
               [duplicated, duplicated],
               subject_ref: "sjira:work-order:7"
             )

    assert refusal["reason"] == "DUPLICATE_OBLIGATION_IDENTITY"
    assert refusal["detail"].identities == [
             "sjira:work-order:7:security:design:SEC-1"
           ]
  end

  test "empty route is refused rather than producing a vacuous receipt" do
    assert {:refused, refusal} =
             GovernanceRoute.compile([], subject_ref: "sjira:work-order:7")

    assert refusal["reason"] == "GATE_RESULTS_REQUIRED"
  end

  test "route replay detects receipt tamper" do
    assert {:ok, obligations, receipt} =
             GovernanceRoute.compile(
               [gate("security", "design", [finding("SEC-1")])],
               subject_ref: "sjira:work-order:7"
             )

    tampered = %{receipt | digest: String.duplicate("0", 64)}

    assert {:refused, refusal} = GovernanceRoute.replay(obligations, tampered)
    assert refusal["reason"] == "GOVERNANCE_ROUTE_RECEIPT_MISMATCH"
  end

  test "route replay detects obligation state invariant violation even when fields are structurally present" do
    assert {:ok, [obligation], _receipt} =
             GovernanceRoute.compile(
               [gate("security", "design", [finding("SEC-1")])],
               subject_ref: "sjira:work-order:7"
             )

    malformed = %{
      obligation
      | standing: :prepared,
        ready_for_do: true,
        authority_ref: nil,
        prepared_receipt_ref: "receipt:x"
    }

    assert {:refused, refusal} = GovernanceObligation.validate(malformed)
    assert refusal["reason"] == "OBLIGATION_STATE_INVARIANT_VIOLATION"
  end

  test "route receipt changes as obligations advance without becoming authority itself" do
    assert {:ok, [proposed], proposed_receipt} =
             GovernanceRoute.compile(
               [gate("security", "design", [finding("SEC-1")])],
               subject_ref: "sjira:work-order:7"
             )

    {:ok, admitted} = GovernanceObligation.admit(proposed, "sha256:admission")
    {:ok, authorized} = GovernanceObligation.authorize(admitted, "odrl:grant:1")
    {:ok, prepared} = GovernanceObligation.prepare(authorized, "receipt:prepared:1")

    prepared_receipt =
      GovernanceRoute.receipt("sjira:work-order:7", [prepared])

    assert proposed_receipt.ready_for_do_count == 0
    assert prepared_receipt.ready_for_do_count == 1
    assert prepared_receipt.standing_counts == %{"prepared" => 1}
    refute proposed_receipt.digest == prepared_receipt.digest

    # Route receipt summarizes standing; it does not itself expose a grant.
    refute Map.has_key?(Map.from_struct(prepared_receipt), :authority_ref)
    refute Map.has_key?(Map.from_struct(prepared_receipt), :prepared_receipt_ref)
  end
end
