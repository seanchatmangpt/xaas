defmodule Xaas.Semantics.VKGRefusalNegativeTest do
  @moduledoc """
  Negative fixtures for the VKG typed refusals inventoried in
  docs/sjira/v26.10.6/plans/vector2-refusal-coverage.md § VKG (B).

  Chicago style: real Xaas.Semantics.VKG modules over the real test engine
  (`Xaas.Test.VKGObservationEngine`), no mocks. Each refusal is asserted at its
  exact typed code, with zero state yield (a clean re-verify afterwards is
  still :ok).
  """

  use ExUnit.Case, async: true

  alias AshR2RML.Refusal
  alias Xaas.Semantics.VKG
  alias Xaas.Semantics.VKG.{Replay, Witness}

  @engine Xaas.Test.VKGObservationEngine

  describe "REFUSED_XAAS_VKG_WITNESS (witness.ex:152)" do
    test "witness whose envelope no longer matches the canonical session is refused, no state yield" do
      assert {:ok, witness} =
               VKG.observe(
                 %{
                   id: "witness-negative",
                   contract_ids: ["customer"],
                   purpose: :engineering_read
                 },
                 engine: @engine
               )

      tampered = %{witness | row_count: witness.row_count + 1}

      assert {:error, %Refusal{code: :REFUSED_XAAS_VKG_WITNESS, subject: :witness} = refusal} =
               Witness.verify(tampered)

      assert refusal.detail == "XaaS VKG witness fields no longer match the canonical session"
      assert refusal.evidence == %{witness_id: witness.id}
      assert refusal.evidence.witness_id != nil

      # zero state yield: the untampered witness still verifies and the
      # observation is unaffected (no rows written, no global mutation)
      assert :ok = Witness.verify(witness)
      assert {:ok, _replayed} = Replay.witness(witness)
    end
  end

  describe "REFUSED_XAAS_VKG_REPLAY (replay.ex:95)" do
    test "replay of a witness whose verification fails is refused as a replay refusal, nothing persisted" do
      assert {:ok, witness} =
               VKG.observe(
                 %{
                   id: "replay-negative",
                   contract_ids: ["order"],
                   purpose: :knowledge_lookup
                 },
                 engine: @engine
               )

      # desynchronize the XaaS envelope from the canonical session: the
      # serialized replay boundary wraps the failed envelope verification in
      # the XaaS replay refusal
      tampered = %{witness | result_sha256: String.duplicate("f", 64)}

      assert {:error, %Refusal{code: :REFUSED_XAAS_VKG_REPLAY, subject: :serialization} = refusal} =
               Replay.serialized_witness(tampered)

      assert refusal.detail == "serialized VKG witness does not preserve result identity"
      assert refusal.evidence == %{witness_id: witness.id}

      # zero state yield: the untampered witness still serializes cleanly
      assert {:ok, receipt} = Replay.serialized_witness(witness)
      assert receipt.result_sha256 == witness.result_sha256
      assert byte_size(receipt.encoded_sha256) == 64
    end
  end

  describe "REFUSED_VKG_EMPTY_CATALOG (vkg.ex:52)" do
    # docs/sjira/v26.10.6: the empty-catalog edge at vkg.ex:52 is reached when
    # Catalog.ids/1 returns [] from a loaded catalog. An empty sources/ dir
    # refuses earlier at the manifest/registry layer (typed Refusal), so this
    # fixture asserts the real fail-closed behavior at that edge: typed
    # refusal, not a crash, no observation minted.
    @tag :tmp_dir
    test "empty source catalog refuses with a typed Refusal, not a crash" do
      empty_root = setup_empty_vkg_root()
      on_exit(fn -> File.rm_rf!(empty_root) end)

      assert {:error, %Refusal{} = refusal} = VKG.observe_all(root: empty_root)

      # the reachable fail-closed edge refuses at the manifest layer before
      # the catalog can load.
      #
      # Structural unreachability of :REFUSED_VKG_EMPTY_CATALOG (vkg.ex:52),
      # proven on deps/ash_r2rml (w185 r2rml mirror, lane W378):
      # observe_all/1 (vkg.ex:38) is the ONLY entry that binds `ids` via the
      # `ids when ids != []` guard; the `[] ->` clause at :52 is exactly the
      # with-else handler for that guard failing on []. Catalog.ids/1 returns
      # Map.keys(registry.contracts); Runtime.catalog/1 is Catalog.load/1
      # (Manifest.load_all -> Registry.admit), and Registry.admit/1 refuses
      # [] outright (deps/ash_r2rml/.../registry.ex:25 "VKG registry requires
      # at least one contract"), so every catalog returned {:ok, _} has >= 1
      # contract, so ids/1 can never yield [] and the guard can never fail
      # with []. No public entry reaches the :52 clause. The clause is dead
      # defensive code; deletion (or guard feeding) is an operator/lib
      # decision, not testable from this lane.
      assert %Refusal{code: :REFUSED_VKG_MANIFEST, subject: :sources} = refusal

      assert refusal.detail == "no VKG source manifests found"
      assert refusal.evidence == %{root: empty_root}
    end
  end

  defp setup_empty_vkg_root do
    root = Path.join(System.tmp_dir!(), "vkg-empty-catalog-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "sources"))
    root
  end
end
