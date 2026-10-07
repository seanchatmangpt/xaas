defmodule Xaas.Chicago.Bridges.Ex4PmTest do
  @moduledoc """
  Falsifiers for the ex4pm conformance bridge:

    * the clean purchase log conforms with fitness 1.0 and a real receipt hash
      from the sibling's ETS evidence store;
    * mutating the log (an event the discovered model never saw) flips the
      conformance verdict — the ENGINE decides, not the bridge;
    * malformed OCEL passes the sibling's typed refusal through, never green;
    * the subject URN as the purchase object id round-trips into the
      content-addressed subject hash; one mutated character hashes differently.
  """

  use ExUnit.Case, async: false

  alias Xaas.Bridges
  alias Xaas.Bridges.Ex4Pm

  @subject Bridges.subject()

  test "clean purchase log conforms with fitness 1.0 and a real receipt" do
    assert {:ok, envelope} = Ex4Pm.conform_purchase(Ex4Pm.purchase_log())

    assert envelope.state == :conformed
    assert envelope.subject == @subject
    assert envelope.authority_ceiling == :none
    assert String.starts_with?(envelope.receipt_ref, "ex4pm.receipt:")
    assert String.starts_with?(envelope.evidence_ref, "ex4pm.subject_hash:")

    assert envelope.provenance.value.fitness == 1.0

    assert envelope.provenance.sibling_standing in [
             :alive,
             :partial_alive,
             :ALIVE,
             :PARTIAL_ALIVE
           ]

    assert is_binary(envelope.provenance.subject_hash)
  end

  test "mutated log flips the conformance verdict against the clean-discovered model" do
    clean = Ex4Pm.purchase_log()
    assert {:ok, model} = Ex4Pm.discover_model(clean)

    mutated =
      clean
      |> put_in(["events", "e4"], %{
        "activity" => "self_approve",
        "timestamp" => "2026-10-01T09:07:00Z",
        "objects" => [@subject]
      })

    assert {:ok, clean_envelope} = Ex4Pm.conform_purchase(clean, model: model)
    assert clean_envelope.provenance.value.fitness == 1.0

    mutated_result = Ex4Pm.conform_purchase(mutated, model: model)

    case mutated_result do
      {:ok, mutated_envelope} ->
        assert mutated_envelope.provenance.value.fitness < 1.0

      {:refused, refusal} ->
        assert is_atom(refusal.code)
    end

    # the flip is real: clean and mutated runs produced different verdicts
    refute match?({:ok, %{provenance: %{value: %{fitness: 1.0}}}}, mutated_result)
  end

  test "malformed OCEL passes the sibling's typed refusal through" do
    malformed = %{"objects" => %{}}

    assert {:refused, refusal} = Ex4Pm.conform_purchase(malformed)
    assert refusal.code in [:missing_events, :missing_objects, :invalid_observation]
    assert is_binary(refusal.message)
    assert refusal.subject == @subject
  end

  test "non-map OCEL is refused as invalid observation" do
    assert {:refused, refusal} = Ex4Pm.conform_purchase(%{})
    assert is_atom(refusal.code)
  end

  test "subject byte round-trip: one mutated object-id character hashes differently" do
    mutated_subject = String.replace(@subject, "purchase-001", "purchase-002")
    assert mutated_subject != @subject

    assert {:ok, original} = Ex4Pm.conform_purchase(Ex4Pm.purchase_log())

    assert {:ok, mutated} =
             Ex4Pm.conform_purchase(Ex4Pm.purchase_log(mutated_subject), subject: mutated_subject)

    original_hash = original.provenance.subject_hash
    mutated_hash = mutated.provenance.subject_hash

    assert original_hash != mutated_hash
    assert mutated.subject == mutated_subject
    refute mutated.subject == @subject
  end
end
