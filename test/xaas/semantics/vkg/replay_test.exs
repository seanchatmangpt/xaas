defmodule Xaas.Semantics.VKG.ReplayTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.VKG
  alias Xaas.Semantics.VKG.Replay

  @engine Xaas.Test.VKGObservationEngine

  test "witness replays through both canonical and XaaS envelopes" do
    assert {:ok, witness} =
             VKG.observe(
               %{
                 id: "replay-customer",
                 contract_ids: ["customer"],
                 purpose: :failure_analysis
               },
               engine: @engine
             )

    assert {:ok, replay} = Replay.witness(witness)
    assert replay.deterministic?
    assert replay.witness_id == witness.id
    assert replay.query_id == witness.query_id
    assert replay.result_sha256 == witness.result_sha256
    assert replay.authority == :NONE
  end

  test "serialized session preserves the sealed result identity" do
    assert {:ok, witness} =
             VKG.observe(
               %{
                 id: "serialize-order",
                 contract_ids: ["order"],
                 purpose: :knowledge_lookup
               },
               engine: @engine
             )

    assert {:ok, receipt} = Replay.serialized_witness(witness)
    assert receipt.deterministic?
    assert receipt.result_sha256 == witness.result_sha256
    assert byte_size(receipt.encoded_sha256) == 64

    encoded = VKG.encode_witness!(witness)
    decoded = Jason.decode!(encoded)
    assert decoded["receipt"]["result_sha256"] == witness.result_sha256
    assert decoded["receipt"]["authority"] == "NONE"
  end

  test "mutated application witness refuses replay" do
    assert {:ok, witness} =
             VKG.observe(
               %{
                 id: "mutation-falsifier",
                 contract_ids: ["customer"],
                 purpose: :engineering_read
               },
               engine: @engine
             )

    changed = %{witness | result_sha256: String.duplicate("0", 64)}

    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_WITNESS}} =
             Replay.witness(changed)
  end
end
