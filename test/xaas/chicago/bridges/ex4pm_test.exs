defmodule Xaas.Chicago.Bridges.Ex4PmTest do
  @moduledoc """
  Court for `Xaas.Bridges.Ex4Pm` — the ex4pm conformance bridge (W650w2).

  Census (2026-10-07, lane W650w2): the Bridges non-graphlaw family had
  dedicated tests for ferroplan + registry (test/xaas/bridges/), pplan + sa2a
  (test/xaas/chicago/bridges/); `Xaas.Bridges.Ex4Pm` had zero direct tests of
  `discover_model/2` or `conform_purchase/2` anywhere in test/ — it was only
  reached indirectly through OCEL/live tests. Semantics family disposition:
  every `lib/xaas/semantics/*.ex` module has a dedicated test file (see
  receipt) → covered.

  All tests run the real ex4pm engine (git dep, pinned), the real inductive
  miner, and the real ETS evidence store (started on demand by the bridge's
  own `ensure_store/1` — infrastructure for evidence, not a mock). Asserts on
  final envelope state, never interactions. Chicago discipline.
  """

  use ExUnit.Case, async: false

  alias Xaas.Bridges
  alias Xaas.Bridges.Ex4Pm

  describe "purchase_log/1 fixture" do
    test "object_type is the purchase OCEL object type" do
      assert Ex4Pm.object_type() == "Purchase"
    end

    test "clean log is submit -> human_release -> settle on the subject object" do
      subject = Bridges.subject()
      log = Ex4Pm.purchase_log(subject)

      assert log["objects"][subject]["type"] == "Purchase"

      activities =
        log["events"]
        |> Enum.sort_by(fn {_id, ev} -> ev["timestamp"] end)
        |> Enum.map(fn {_id, ev} -> ev["activity"] end)

      assert activities == ["submit", "human_release", "settle"]
      # every event is attached to the subject object
      for {_id, ev} <- log["events"], do: assert(ev["objects"] == [subject])
    end
  end

  describe "discover_model/2" do
    test "discovers a real POWL model from the clean purchase log" do
      assert {:ok, model} = Ex4Pm.discover_model(Ex4Pm.purchase_log())
      # the sibling's real discovery artifact: a non-empty POWL model map
      assert is_map(model)
      assert map_size(model) > 0
    end

    test "malformed OCEL refuses with a typed passthrough, never green" do
      assert {:refused, refusal} = discover_malformed()
      assert is_atom(refusal.code)
      assert is_binary(refusal.message) and refusal.message != ""

      # the sibling's refusal is passed through with the bridge envelope's
      # subject and refused state, not swallowed into a generic failure
      assert refusal.subject == Bridges.subject()
      assert refusal.state == :refused
    end
  end

  describe "conform_purchase/2" do
    test "clean log conforms against its own discovered model with real receipt evidence" do
      log = Ex4Pm.purchase_log()

      assert {:ok, envelope} = Ex4Pm.conform_purchase(log)
      assert envelope.state == :conformed
      assert envelope.subject == Bridges.subject()
      assert envelope.authority_ceiling == :none
      assert envelope.claim == "ex4pm purchase conformance"

      # receipt evidence comes from the engine's real observed run
      assert String.starts_with?(envelope.receipt_ref, "ex4pm.receipt:")
      assert String.starts_with?(envelope.evidence_ref, "ex4pm.subject_hash:")

      # provenance carries the engine's real verdict fields
      assert is_binary(envelope.provenance.subject_hash)
      assert envelope.provenance.subject_hash != ""
      assert is_atom(envelope.provenance.sibling_standing)
      assert is_atom(envelope.provenance.engine)
      assert envelope.provenance.algorithm != nil
      # a perfect self-conformance: perfect fitness, zero deviations
      assert envelope.provenance.value.fitness == 1.0
      assert envelope.provenance.value.deviations == %{}
      assert envelope.provenance.value.deviation_count == 0
    end

    test "mutation falsifier: an event the model never saw flips the conformance verdict" do
      clean = Ex4Pm.purchase_log()
      assert {:ok, model} = Ex4Pm.discover_model(clean)

      # mutate: a forged pre-settle event the discovered model never observed
      mutated =
        put_in(clean, ["events", "e0"], %{
          "activity" => "settle",
          "timestamp" => "2026-10-01T08:55:00Z",
          "objects" => [Bridges.subject()]
        })

      result = Ex4Pm.conform_purchase(mutated, model: model)

      case result do
        {:refused, refusal} ->
          assert is_atom(refusal.code)

        {:ok, envelope} ->
          # verdict must flip: sub-1 fitness with a real deviation
          assert envelope.provenance.value.fitness < 1.0
          assert envelope.provenance.value.deviation_count >= 1
          assert envelope.receipt_ref != nil
      end
    end

    test "explicit subject option byte-round-trips into the envelope" do
      subject = "#{Bridges.subject()}-ex4pm-#{System.unique_integer([:positive])}"
      log = Ex4Pm.purchase_log(subject)

      assert {:ok, envelope} = Ex4Pm.conform_purchase(log, subject: subject)
      assert envelope.subject == subject

      assert {:refused, refusal} = Ex4Pm.conform_purchase(%{"objects" => %{}, "events" => %{}},
               subject: subject
             )

      assert refusal.subject == subject
    end
  end

  # discover_model on an empty-but-shaped log: exercises the ingest-refusal
  # path in isolation from conform's own refusals.
  defp discover_malformed do
    Ex4Pm.discover_model(%{"objects" => %{}, "events" => %{}})
  end
end
