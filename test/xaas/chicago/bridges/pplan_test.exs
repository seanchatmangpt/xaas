defmodule Xaas.Chicago.Bridges.PPlanTest do
  @moduledoc """
  Falsifiers for the P-PLAN agentic-payment spine:

    * the purchase model is the plan ash_pplan actually manufactures at this pin;
    * the subject round-trips byte-for-byte as the run identity (one mutated
      character is a different run - no fuzzy match);
    * an over-limit purchase parks as a real durable run (await_human_release)
      and resumes only on release;
    * envelopes carry evidence from real durable Reactor executions, never
      inherited standing.

  The durable park is now the ash_pplan facade surface (pin 5f10c97:
  AshPPlan.A2A.Facade over AshPPlan.Reactor.Durable.Engine; the old
  capture_continuation ETF continuation was removed at this pin). Parked runs
  live in a real AshPPlan.Reactor.Durable.Store.Ets store, so each test mints
  its own subject (a store outlives a single test) and the suite starts its
  own store process, pointing the :xaas :pplan_durable_store env at it.
  """

  use ExUnit.Case, async: false

  alias Xaas.Bridges
  alias Xaas.Bridges.PPlan

  @base_subject Bridges.subject()
  @plan_iri "https://w3id.org/ash-pplan#SubscriptionRenewal"

  setup do
    {:ok, _} = Application.ensure_all_started(:reactor)

    {:ok, store} = AshPPlan.Reactor.Durable.Store.Ets.start_link([])

    previous = Application.get_env(:xaas, :pplan_durable_store)
    Application.put_env(:xaas, :pplan_durable_store, store)

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:xaas, :pplan_durable_store, previous)
    end)

    %{store: store}
  end

  test "purchase_model is the manufactured SubscriptionRenewal spine" do
    assert {:ok, plan} = PPlan.purchase_model()
    assert plan.iri == @plan_iri

    step_iris = Enum.map(plan.steps, & &1.iri)
    assert "https://w3id.org/ash-pplan#AuthorizePayment" in step_iris
    assert "https://w3id.org/ash-pplan#RenewSubscription" in step_iris
  end

  test "under-limit purchase completes on the real durable engine" do
    subject = unique_subject()

    assert {:ok, envelope} =
             PPlan.run_purchase(%{"amount" => 100, "limit" => 500}, subject: subject)

    assert envelope.state == :completed
    assert envelope.subject == subject
    assert envelope.authority_ceiling == :none
    assert envelope.standing == "PARTIAL_ALIVE"
    assert envelope.receipt_ref == "ash_pplan.durable_run:" <> subject
    assert envelope.provenance.run_id == subject
    assert envelope.provenance.plan_iri == @plan_iri
  end

  test "over-limit purchase parks as await_human_release and resumes on release", %{store: store} do
    subject = unique_subject()

    assert {:ok, parked} =
             PPlan.run_purchase(%{"amount" => 1500, "limit" => 500}, subject: subject)

    assert parked.state == :awaiting_human_release
    assert parked.subject == subject
    assert parked.provenance.reactor_state == :halted
    assert parked.receipt_ref != nil
    assert String.starts_with?(parked.evidence_ref, "ash_pplan.durable_run:")

    continuation = parked.provenance.continuation
    assert %AshPPlan.Reactor.Durable.Record{} = continuation
    assert continuation.id == subject
    assert continuation.plan_iri == @plan_iri
    assert continuation.status == :waiting

    assert {:ok, released} =
             PPlan.release_purchase(continuation, release: "operator-release-77")

    assert released.state == :completed
    assert released.subject == subject
    assert released.standing == "PARTIAL_ALIVE"
    assert released.provenance.resumed_from_continuation == subject

    # the parked signal was consumed exactly once and the release reached the plan
    signals = AshPPlan.Reactor.Durable.Store.Ets.signals(store, subject)
    assert [%{name: "human_release", consumed_at: consumed}] = signals
    refute is_nil(consumed)
  end

  test "subject byte round-trip: one mutated character is a different run identity" do
    subject = unique_subject()
    mutated_subject = String.replace(subject, "urn:", "ura:", global: false)
    assert mutated_subject != subject

    assert {:ok, original} =
             PPlan.run_purchase(%{"amount" => 1500, "limit" => 500}, subject: subject)

    assert {:ok, mutated} =
             PPlan.run_purchase(%{"amount" => 1500, "limit" => 500}, subject: mutated_subject)

    assert original.subject == subject
    assert mutated.subject == mutated_subject
    assert mutated.provenance.run_id == mutated_subject
    assert original.provenance.run_id != mutated.provenance.run_id
  end

  test "release without a parked run is refused, not guessed" do
    subject = unique_subject()

    forged = %AshPPlan.Reactor.Durable.Record{id: subject}

    assert {:refused, refusal} = PPlan.release_purchase(forged)
    assert refusal.code == :no_such_run
    assert refusal.subject == subject
  end

  defp unique_subject do
    "#{@base_subject}-#{System.unique_integer([:positive])}"
  end
end
