defmodule Xaas.PradyotChicagoFabricCourtTest do
  use ExUnit.Case, async: true
  alias Xaas.Tunnel.{Capabilities, Fabric, Receipt}
  @subject "urn:chicago:agentic-payment:purchase-001"

  test "human or fabric projection cannot mint DO authority" do
    assert {:refused, {:authority_ceiling, "actuate"}} = Capabilities.admit("actuate")
    assert {:refused, {:authority_ceiling, "actuate"}} = Fabric.transition(Fabric.new(), :actuate)
  end

  test "succeeded intent without evidence cannot promote standing" do
    facts = %{intent: %{id: @subject, status: :succeeded}, receipts: [], epoch: nil}
    assert {:refused, :receipt_missing_for_succeeded_intent} = Fabric.reconcile(facts)
  end

  test "receipt replay is subject-bound and stale mutation is refused" do
    sealed = %{"subject" => @subject, "outcome" => "ALIVE"}
    digest = Receipt.digest(sealed)
    assert :ok = Receipt.verify_replay(sealed, digest)
    stale = %{sealed | "subject" => @subject <> "-OTHER"}
    assert {:refused, :replay_digest_mismatch} = Receipt.verify_replay(stale, digest)
  end

  test "post-dispatch executing state without sealed evidence awaits observation" do
    epoch = %{id: @subject, state: :running, leased_to: "provider", lease_expires_at: DateTime.add(DateTime.utc_now(), 60, :second)}
    assert {:await_execution, @subject} = Fabric.reconcile(%{intent: %{id: @subject, status: :executing}, receipts: [], epoch: epoch})
  end
end
