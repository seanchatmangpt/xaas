defmodule Xaas.Ultracode.SemanticWorkFalsifierTest do
  @moduledoc """
  SJ-001 qualifier falsifiers against `SemanticWork.admit/2`'s digest binding.

  Each test is attributable: it first asserts a positive control (the untampered
  real descriptor is admitted and the field under attack really IS derived from
  the carried admitted snapshot), then tampers exactly that field with every
  digest left intact, and asserts admission refuses with a typed reason.

  These are expected to FAIL against 2c825b5: `AdmissionBinding` checks the
  descriptor's `base_sha`, `repository_identity`, `work_order_iri` and the
  bridge's identity / repository / base_sha / definition_digest against the
  snapshot, but not the bridge's `subject` / `requires` (acceptance, courts,
  falsifiers) nor the descriptor's `dependencies`, although all of those are
  deterministic projections of the admitted snapshot in the emitter's shape
  (`docs/sjira/v26.9.21/e2e_project.exs`) and are persisted on the Run
  (`dependency_evidence`, `semantic_bridge`) and echoed into the exported
  receipt (`SemanticReceipt.export/1` reads `bridge.requires.courts`).

  The fixture is the committed byte-for-byte output of the real graph-side
  projection, the same one `semantic_work_test.exs` attacks.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.SemanticWork

  @real_descriptor Path.expand(
                     "../../../docs/sjira/v26.9.21/receipts/sj-001/evidence/descriptor.json",
                     __DIR__
                   )
  @external_resource @real_descriptor

  defp real_descriptor, do: @real_descriptor |> File.read!() |> Jason.decode!()

  defp assert_snapshot_mismatch(result) do
    assert {:error, {:refused_semantic_work, {:admitted_snapshot_mismatch, _field}}} = result
  end

  describe "bridge fields the snapshot determines" do
    test "bridge.requires (acceptance / courts / falsifiers) is the snapshot's" do
      descriptor = real_descriptor()
      snapshot = descriptor["admitted_work_order"]

      # positive control: the emitter projects requires FROM the snapshot
      assert descriptor["bridge"]["requires"] == %{
               "acceptance" => snapshot["acceptance"],
               "courts" => snapshot["required_courts"],
               "falsifiers" => snapshot["falsifiers"]
             }

      # :auto is refused by the landed binding law (guard WIP, see SemanticWork moduledoc)
      for mode <- [:snapshot] do
        assert {:ok, _} = SemanticWork.admit(descriptor, binding: mode)
      end

      # every digest intact; only the required courts / falsifiers are weakened
      weakened = put_in(descriptor, ["bridge", "requires", "courts"], [])
      emptied = put_in(descriptor, ["bridge", "requires", "falsifiers"], [])

      for tampered <- [weakened, emptied], mode <- [:snapshot] do
        assert_snapshot_mismatch(SemanticWork.admit(tampered, binding: mode))
      end
    end

    test "bridge.subject is the snapshot's" do
      descriptor = real_descriptor()

      assert descriptor["bridge"]["subject"] == descriptor["admitted_work_order"]["subject"]
      assert {:ok, _} = SemanticWork.admit(descriptor, binding: :snapshot)

      tampered = put_in(descriptor, ["bridge", "subject"], "some-other-subject")

      # :auto is refused by the landed binding law (guard WIP, see SemanticWork moduledoc)
      for mode <- [:snapshot] do
        assert_snapshot_mismatch(SemanticWork.admit(tampered, binding: mode))
      end
    end
  end

  describe "descriptor fields the snapshot determines" do
    test "dependency edges cannot be injected when the admitted snapshot has none" do
      descriptor = real_descriptor()

      # positive control: nothing upstream was admitted
      assert descriptor["admitted_work_order"]["dependencies"] == []
      assert descriptor["dependencies"] == []
      assert {:ok, _} = SemanticWork.admit(descriptor, binding: :snapshot)

      injected =
        Map.put(descriptor, "dependencies", [
          %{
            "work_order_iri" => "urn:semantic-jira:work-order:SJ-FAKE",
            "required_standing" => "ALIVE",
            "observed_standing" => "ALIVE",
            "receipt_iri" => "urn:fabricated:receipt:1",
            "receipt_digest" => "sha256:" <> String.duplicate("b", 64)
          }
        ])

      # :auto is refused by the landed binding law (guard WIP, see SemanticWork moduledoc)
      for mode <- [:snapshot] do
        assert_snapshot_mismatch(SemanticWork.admit(injected, binding: mode))
      end
    end
  end
end
