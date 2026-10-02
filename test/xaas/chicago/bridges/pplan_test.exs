defmodule Xaas.Chicago.Bridges.PPlanTest do
  @moduledoc """
  Falsifiers for the P-PLAN agentic-payment spine:

    * the purchase model is the plan ash_pplan actually manufactures at this pin;
    * the subject round-trips byte-for-byte as the run identity (one mutated
      character is a different run — no fuzzy match);
    * an over-limit purchase parks as a real durable continuation
      (await_human_release) and resumes only on release;
    * envelopes carry receipts from real Reactor executions, never inherited
      standing.
  """

  use ExUnit.Case, async: false

  alias Xaas.Bridges
  alias Xaas.Bridges.PPlan

  @subject Bridges.subject()
  @plan_iri "https://w3id.org/ash-pplan#SubscriptionRenewal"

  test "purchase_model is the manufactured SubscriptionRenewal spine" do
    assert {:ok, plan} = PPlan.purchase_model()
    assert plan.iri == @plan_iri

    step_iris = Enum.map(plan.steps, & &1.iri)
    assert "https://w3id.org/ash-pplan#AuthorizePayment" in step_iris
    assert "https://w3id.org/ash-pplan#RenewSubscription" in step_iris
  end

  test "under-limit purchase completes on the real Reactor with a receipt" do
    assert {:ok, envelope} = PPlan.run_purchase(%{"amount" => 100, "limit" => 500})

    assert envelope.state == :completed
    assert envelope.subject == @subject
    assert envelope.authority_ceiling == :none
    assert envelope.standing == "PARTIAL_ALIVE"
    assert is_binary(envelope.receipt_ref)
    assert envelope.provenance.run_id == @subject
    assert envelope.provenance.plan_iri == @plan_iri
  end

  test "over-limit purchase parks as await_human_release and resumes on release" do
    assert {:ok, parked} = PPlan.run_purchase(%{"amount" => 1500, "limit" => 500})

    assert parked.state == :awaiting_human_release
    assert parked.subject == @subject
    assert parked.provenance.reactor_state == :halted
    assert parked.receipt_ref != nil
    assert String.starts_with?(parked.evidence_ref, "ash_pplan.continuation:")

    continuation = parked.provenance.continuation
    assert %AshPPlan.Continuation{} = continuation
    assert continuation.run_id == @subject
    assert continuation.plan_iri == @plan_iri

    assert {:ok, released} =
             PPlan.release_purchase(continuation, release: "operator-release-77")

    assert released.state == :completed
    assert released.subject == @subject
    assert released.standing == "PARTIAL_ALIVE"
    assert released.provenance.resumed_from_continuation == continuation.id
  end

  test "subject byte round-trip: one mutated character is a different run identity" do
    mutated_subject = String.replace(@subject, "purchase-001", "purchase-002")
    assert mutated_subject != @subject

    assert {:ok, original} = PPlan.run_purchase(%{"amount" => 1500, "limit" => 500})
    assert {:ok, mutated} = PPlan.run_purchase(%{"amount" => 1500, "limit" => 500}, subject: mutated_subject)

    assert original.subject == @subject
    assert mutated.subject == mutated_subject
    refute mutated.subject == @subject
    assert mutated.provenance.run_id == mutated_subject
    assert original.provenance.run_id != mutated.provenance.run_id
  end

  test "release without a parked continuation is refused, not guessed" do
    fake = %AshPPlan.Continuation{
      id: "sha256:0000000000000000000000000000000000000000000000000000000000000000",
      schema_version: 2,
      plan_iri: @plan_iri,
      run_id: @subject,
      ash_pplan_version: AshPPlan.version(),
      reactor_version: "test",
      codec_id: "erlang-external-term",
      codec_version: "1",
      payload: <<0, 1, 2>>,
      payload_sha256: String.duplicate("0", 64)
    }

    assert {:refused, refusal} = PPlan.release_purchase(fake)
    # a forged envelope is refused by the real validator — whichever integrity
    # check fires first (digest, codec, or version identity) is the typed truth
    assert refusal.code in [
             :continuation_payload_digest_mismatch,
             :codec_decode_failed,
             :reactor_version_mismatch
           ]

    assert refusal.subject == @subject
  end
end
