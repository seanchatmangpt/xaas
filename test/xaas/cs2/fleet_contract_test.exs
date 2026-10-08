defmodule Xaas.CS2.FleetContractTest do
  @moduledoc """
  W650h9 depth court for Xaas.CS2.FleetContract (recensus top-15, unclaimed).

  Real invariants over the representation boundary: subject gate, evidence
  atomization, authority ceiling. Mutation rationale per test.
  """

  use ExUnit.Case, async: true

  alias Xaas.CS2.FleetContract

  @subject "https://chatman.ai/cs2#RFC-CS2-001"

  describe "engineer_workflow/1 admitted path" do
    test "admitted packet with atom keys yields engineer workflow with authority NONE" do
      # Mutation rationale: kills `authority: "NONE"` -> "FULL" and the
      # subject-equality gate mutating to always-true (any subject admitted).
      packet = %{subject: @subject, evidence_id: "ev-1"}

      assert {:ok, wf} = FleetContract.engineer_workflow(packet)
      assert wf["kind"] == "cs2.engineer_workflow"
      assert wf["contract"] == "cs2-fleet-contract/26.9.27"
      assert wf["subject"] == @subject
      assert wf["authority"] == "NONE"
      assert wf["source"] == "semantic_jira"
    end

    test "atom keys are atomized to strings, nested maps and lists included" do
      # Mutation rationale: kills dropping `strings/1` normalization (packet
      # stored with atom keys would diverge from string-keyed consumers).
      packet = %{
        subject: @subject,
        meta: %{track: "sponsor", tags: ["a", :b]}
      }

      assert {:ok, wf} = FleetContract.engineer_workflow(packet)
      evidence = wf["evidence"]
      assert evidence["subject"] == @subject
      assert %{meta: %{track: "sponsor", tags: ["a", :b]}} = packet
      assert evidence["meta"] == %{"track" => "sponsor", "tags" => ["a", :b]}
    end

    test "explicit source is passed through, not overwritten" do
      # Mutation rationale: kills `packet["source"] || "semantic_jira"` folding
      # to the literal default.
      packet = Map.put(%{subject: @subject}, "source", "a2a")

      assert {:ok, wf} = FleetContract.engineer_workflow(packet)
      assert wf["source"] == "a2a"
    end
  end

  describe "engineer_workflow/1 refusal paths" do
    test "wrong subject is a typed refusal naming the offending subject" do
      # Mutation rationale: kills the subject gate degrading to {:ok, ...} on
      # foreign subjects (representation boundary creating false authority).
      assert {:error, {:unsupported_cs2_subject, "https://elsewhere.example/rfc-999"}} =
               FleetContract.engineer_workflow(%{subject: "https://elsewhere.example/rfc-999"})
    end

    test "non-map packet is a typed refusal, not a crash" do
      # Mutation rationale: kills deleting the non-map function head (would
      # raise FunctionClauseError instead of returning a typed refusal).
      assert {:error, {:unsupported_cs2_packet, :atom_packet}} =
               FleetContract.engineer_workflow(:atom_packet)

      assert {:error, {:unsupported_cs2_packet, [%{}]}} =
               FleetContract.engineer_workflow([%{}])
    end
  end
end
