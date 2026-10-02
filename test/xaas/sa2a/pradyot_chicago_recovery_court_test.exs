defmodule Xaas.PradyotChicagoRecoveryCourtTest do
  use ExUnit.Case, async: true
  alias Xaas.Runtime.FOND.{Edge, Graph, Executor, Receipt}
  alias Xaas.Ultracode.RecoveryPolicy
  @subject "urn:chicago:agentic-payment:purchase-001"

  test "provider unavailable before dispatch preserves a lawful alternative" do
    primary = Edge.new(:primary, fn _ -> {:error, :provider_unavailable} end, capabilities: [:purchase], cost: 1)
    alternate = Edge.new(:alternate, fn _ -> {:ok, {@subject, :authorized_bounded_purchase}} end, capabilities: [:purchase], cost: 2)
    graph = Graph.new([primary, alternate])
    assert {:ok, {@subject, :authorized_bounded_purchase}, :alternate, rerouted} = Executor.run(graph, :purchase, @subject)
    assert MapSet.member?(rerouted.excluded, :primary)
    refute MapSet.member?(rerouted.excluded, :alternate)
  end

  test "unknown outcome after dispatch is fail-safe and never blind-chain replay" do
    assert RecoveryPolicy.observe(:unknown_after_dispatch, false) == :error
    assert RecoveryPolicy.decide(:unknown_after_dispatch, false) == :await_cron
    refute RecoveryPolicy.decide(:unknown_after_dispatch, false) == :chain
  end

  test "runtime receipt preserves the exact Chicago subject" do
    receipt = Receipt.new(@subject, :alternate, :authorized_bounded_purchase)
    assert receipt.subject == @subject
    assert is_binary(Receipt.replay_key(receipt))
    refute Receipt.replay_key(receipt) == Receipt.replay_key(%{receipt | subject: @subject <> "-OTHER"})
  end
end
