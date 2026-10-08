defmodule Xaas.CausalReceipt.ProcessReceiptDepthTest do
  @moduledoc """
  Depth court for `Xaas.CausalReceipt.ProcessReceipt` (W984cx3, v26.10.6
  coverage burn-down). The module had zero test references before this
  court.

  Chicago-style: real structs, real sha256 chaining, assertions on final
  state — no mocks, no doubles. Every test names the mutation it kills.
  """

  use ExUnit.Case, async: true

  alias Xaas.CausalReceipt.ProcessReceipt

  defp base_fields(overrides \\ %{}) do
    Map.merge(
      %{
        observation_ids: ["obs-1", "obs-2"],
        admitted_observation_hash: "hash-obs",
        ontology_hash: "hash-ont",
        actuation_identity: "act-1",
        consequence_identity: "cons-1",
        valid_time: ~U[2026-10-07 00:00:00Z],
        observation_time: ~U[2026-10-07 00:00:01Z]
      },
      overrides
    )
  end

  defp signed_receipt(overrides \\ %{}) do
    {:ok, receipt} = ProcessReceipt.new(base_fields(overrides))
    {:ok, signed} = ProcessReceipt.sign(receipt)
    signed
  end

  test "new/1 refuses incomplete receipts naming every missing required field" do
    # Mutation killed: deleting or weakening the missing-field filter in
    # new/1 (e.g. dropping `is_nil` check or a required field from
    # @required_fields) — this test fails because the refusal must name the
    # full set, not a subset.
    {:error, {:incomplete_receipt, missing}} =
      ProcessReceipt.new(%{
        observation_ids: ["obs-1"],
        ontology_hash: "hash-ont"
      })

    assert Enum.sort(missing) ==
             Enum.sort([
               :admitted_observation_hash,
               :actuation_identity,
               :consequence_identity,
               :valid_time,
               :observation_time
             ])
  end

  test "episode_identity is deterministic and collision-free on real field differences" do
    # Mutation killed: replacing episode_identity/1's content fingerprint
    # with a constant/random value, or dropping a bound field from the
    # fingerprint map — either mutation changes these assertions.
    {:ok, a} = ProcessReceipt.new(base_fields())
    {:ok, b} = ProcessReceipt.new(base_fields())

    assert a.episode_id == b.episode_id
    assert is_binary(a.episode_id) and byte_size(a.episode_id) == 64

    {:ok, c} = ProcessReceipt.new(base_fields(%{consequence_identity: "cons-2"}))
    refute c.episode_id == a.episode_id

    # valid_time enters through json_safe canonicalization: equal instants in
    # different DateTime structs with identical ISO form still collide.
    {:ok, d} =
      ProcessReceipt.new(
        base_fields(%{valid_time: DateTime.add(~U[2026-10-07 00:00:00Z], 0, :second)})
      )

    assert d.episode_id == a.episode_id
  end

  test "sign/verify round-trips; chaining binds predecessor_receipt" do
    # Mutation killed: (a) dropping predecessor_receipt from chain_input in
    # sign/1 — child hashes would equal standalone hashes; (b) breaking the
    # hash_mismatch arm of verify/1.
    {:ok, genesis} = ProcessReceipt.new(base_fields())
    {:ok, signed_genesis} = ProcessReceipt.sign(genesis)

    {:ok, child} =
      ProcessReceipt.new(base_fields(%{predecessor_receipt: signed_genesis.receipt_hash}))

    {:ok, signed_child} = ProcessReceipt.sign(child)

    refute signed_child.receipt_hash == signed_genesis.receipt_hash
    assert :ok = ProcessReceipt.verify(signed_genesis)
    assert :ok = ProcessReceipt.verify(signed_child)
  end

  test "verify/1 refuses tampering with any bound field after signing" do
    # Mutation killed: weakening verify/1 to check only schema completeness
    # (or only that receipt_hash is non-nil) — a mutated consequence would
    # then pass. Also kills removal of the receipt_hash: nil clause.
    signed = signed_receipt()
    assert :ok = ProcessReceipt.verify(signed)

    tampered = %{signed | consequence_identity: "tampered"}
    {:error, {:hash_mismatch, expected: stored, actual: recomputed}} =
      ProcessReceipt.verify(tampered)

    assert stored == signed.receipt_hash
    refute recomputed == stored

    {:error, {:hash_mismatch, expected: nil, actual: nil}} =
      ProcessReceipt.verify(%{signed | receipt_hash: nil})
  end

  test "lineage/7 stages reconstruct in order; diff/2 surfaces exact field divergence" do
    # Mutation killed: (a) reordering or dropping lineage stages or the
    # first_non_nil fallbacks in lineage/1; (b) narrowing diff/2's field
    # iteration to a subset of @all_fields — the consequence/stability
    # divergence falsifier would then silently pass.
    signed = signed_receipt()

    lineage = ProcessReceipt.lineage(signed)

    assert Enum.map(lineage, &elem(&1, 0)) ==
             [:observation, :knowledge, :planning, :intent, :do, :consequence, :receipt]

    assert lineage[:observation] == "hash-obs"
    # ontology_hash supplied -> knowledge stage reconstructs, planning/intent absent.
    assert lineage[:knowledge] == "hash-ont"
    # Optional stages with no backing fields surface as {stage, nil}, never
    # silently omitted (the lineage/1 honest-absence invariant).
    assert Enum.find(lineage, fn {s, _} -> s == :planning end) |> elem(1) |> is_nil()
    assert Enum.find(lineage, fn {s, _} -> s == :intent end) |> elem(1) |> is_nil()
    assert lineage[:do] == "act-1"
    assert lineage[:consequence] == "cons-1"
    assert lineage[:receipt] == signed.receipt_hash

    {:ok, left} = ProcessReceipt.new(base_fields())
    {:ok, right} = ProcessReceipt.new(base_fields(%{consequence_identity: "cons-2"}))
    {:ok, signed_left} = ProcessReceipt.sign(left)
    {:ok, signed_right} = ProcessReceipt.sign(right)

    d = ProcessReceipt.diff(signed_left, signed_right)

    assert d[:consequence_identity] == {"cons-1", "cons-2"}
    refute Map.has_key?(d, :ontology_hash)
    # diff/2 compares every field in @all_fields: the differing
    # consequence_identity also changes the derived episode_id and the
    # signed receipt_hash, so exactly those three keys appear.
    assert d |> Map.keys() |> Enum.sort() ==
             [:consequence_identity, :episode_id, :receipt_hash]
  end
end
