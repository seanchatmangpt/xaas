defmodule Xaas.CausalReceipt.ProcessReceiptTest do
  @moduledoc """
  Chicago-style qualification for `Xaas.CausalReceipt.ProcessReceipt` --
  real struct construction, real SHA-256 Merkle chaining, real lineage
  traversal, and real diffing. No mocking: this module has no external
  collaborator to fake, only deterministic pure functions over real input
  data, so every assertion is on real returned state (struct fields, hash
  values, diff maps) per this repo's Chicago-style testing discipline.

  Exercises the ticket's four named falsifiers directly
  (`docs/jira/v26.9.11/unified-causal-receipt.md`):
  1. tamper after signing must fail `verify/1`
  2. a receipt missing a required field must be refused, not accepted
  3. two receipts for genuinely different episodes must not share an
     `episode_id`
  4. receipt diffing must detect a real divergence in `consequence_identity`
     / `stability_result` between two receipts sharing a
     `predecessor_receipt`
  """

  use ExUnit.Case, async: true

  alias Xaas.CausalReceipt.ProcessReceipt

  defp base_fields(overrides \\ %{}) do
    Map.merge(
      %{
        observation_ids: ["obs-1", "obs-2"],
        admitted_observation_hash: "obs-hash-abc",
        ontology_hash: "ontology-hash-abc",
        actuation_identity: "actuation-1",
        consequence_identity: "consequence-1",
        valid_time: ~U[2026-09-11 00:00:00Z],
        observation_time: ~U[2026-09-10 23:00:00Z]
      },
      overrides
    )
  end

  describe "new/1" do
    test "builds a receipt with a deterministically derived episode_id when complete" do
      assert {:ok, receipt} = ProcessReceipt.new(base_fields())
      assert is_binary(receipt.episode_id)
      assert receipt.receipt_hash == nil
      assert receipt.observation_ids == ["obs-1", "obs-2"]
    end

    test "refuses (incomplete_receipt) when a required field is missing" do
      fields = base_fields() |> Map.delete(:admitted_observation_hash)

      assert {:error, {:incomplete_receipt, missing}} = ProcessReceipt.new(fields)
      assert :admitted_observation_hash in missing
    end

    test "refuses when a required field is present but nil" do
      fields = base_fields(%{consequence_identity: nil})

      assert {:error, {:incomplete_receipt, missing}} = ProcessReceipt.new(fields)
      assert :consequence_identity in missing
    end

    test "accepts an explicit episode_id override instead of deriving one" do
      assert {:ok, receipt} = ProcessReceipt.new(base_fields(%{episode_id: "explicit-episode"}))
      assert receipt.episode_id == "explicit-episode"
    end
  end

  describe "episode_identity/1 -- deterministic episode identity falsifier" do
    test "identical episode-identifying fields produce the same episode_id" do
      {:ok, a} = ProcessReceipt.new(base_fields())
      {:ok, b} = ProcessReceipt.new(base_fields())

      assert a.episode_id == b.episode_id
    end

    test "genuinely different episodes never collide on episode_id" do
      {:ok, a} = ProcessReceipt.new(base_fields())
      {:ok, b} = ProcessReceipt.new(base_fields(%{consequence_identity: "consequence-2"}))

      refute a.episode_id == b.episode_id
    end
  end

  describe "sign/1 and verify/1 -- Merkle chaining and tamper falsifier" do
    test "a freshly signed receipt verifies successfully" do
      {:ok, receipt} = ProcessReceipt.new(base_fields())
      {:ok, signed} = ProcessReceipt.sign(receipt)

      assert is_binary(signed.receipt_hash)
      assert ProcessReceipt.verify(signed) == :ok
    end

    test "signing chains against predecessor_receipt (Merkle chaining)" do
      {:ok, r1} = ProcessReceipt.new(base_fields())
      {:ok, signed1} = ProcessReceipt.sign(r1)

      {:ok, r2} = ProcessReceipt.new(base_fields(%{predecessor_receipt: signed1.receipt_hash}))
      {:ok, signed2} = ProcessReceipt.sign(r2)

      {:ok, r2_no_pred} = ProcessReceipt.new(base_fields())
      {:ok, signed2_no_pred} = ProcessReceipt.sign(r2_no_pred)

      refute signed2.receipt_hash == signed2_no_pred.receipt_hash
      assert ProcessReceipt.verify(signed2) == :ok
    end

    test "refuses to sign an incomplete receipt even if constructed via struct/2 directly" do
      incomplete = %ProcessReceipt{
        observation_ids: ["obs-1"],
        admitted_observation_hash: "h",
        ontology_hash: "h2",
        actuation_identity: nil,
        consequence_identity: "c",
        valid_time: ~U[2026-09-11 00:00:00Z],
        observation_time: ~U[2026-09-10 23:00:00Z]
      }

      assert {:error, {:incomplete_receipt, missing}} = ProcessReceipt.sign(incomplete)
      assert :actuation_identity in missing
    end

    test "tampering with a bound identity after signing fails verification" do
      {:ok, receipt} = ProcessReceipt.new(base_fields())
      {:ok, signed} = ProcessReceipt.sign(receipt)

      tampered = %{signed | consequence_identity: "tampered-consequence"}

      assert {:error, {:hash_mismatch, expected: expected, actual: actual}} =
               ProcessReceipt.verify(tampered)

      assert expected == signed.receipt_hash
      refute actual == expected
    end

    test "an unsigned receipt (nil receipt_hash) fails verification rather than passing vacuously" do
      {:ok, receipt} = ProcessReceipt.new(base_fields())

      assert {:error, {:hash_mismatch, expected: nil, actual: nil}} =
               ProcessReceipt.verify(receipt)
    end
  end

  describe "lineage/1" do
    test "reconstructs the full ID(O)->ID(K)->ID(P)->ID(Intent)->ID(DO)->ID(Consequence)->ID(R) chain" do
      {:ok, receipt} =
        ProcessReceipt.new(
          base_fields(%{
            causal_admission_hash: "causal-1",
            planning_problem_hash: "plan-1",
            policy_hash: "policy-1",
            stability_result: "stable"
          })
        )

      {:ok, signed} = ProcessReceipt.sign(receipt)

      lineage = ProcessReceipt.lineage(signed)

      assert lineage == [
               {:observation, "obs-hash-abc"},
               {:knowledge, "causal-1"},
               {:planning, "plan-1"},
               {:intent, "policy-1"},
               {:do, "actuation-1"},
               {:consequence, "consequence-1"},
               {:receipt, signed.receipt_hash}
             ]
    end

    test "an optional stage with no backing field surfaces honestly as nil, not fabricated" do
      {:ok, receipt} = ProcessReceipt.new(base_fields())
      {:ok, signed} = ProcessReceipt.sign(receipt)

      lineage = ProcessReceipt.lineage(signed)

      assert {:planning, nil} in lineage
      assert {:intent, nil} in lineage
    end
  end

  describe "diff/2 -- receipt diffing falsifier" do
    test "reports no difference for two receipts with identical fields" do
      {:ok, a} = ProcessReceipt.new(base_fields())
      {:ok, b} = ProcessReceipt.new(base_fields())

      assert ProcessReceipt.diff(a, b) == %{}
    end

    test "detects a real divergence in consequence_identity between receipts sharing a predecessor" do
      predecessor = "shared-predecessor-hash"

      {:ok, a} =
        ProcessReceipt.new(base_fields(%{predecessor_receipt: predecessor}))

      {:ok, b} =
        ProcessReceipt.new(
          base_fields(%{predecessor_receipt: predecessor, consequence_identity: "consequence-2"})
        )

      diff = ProcessReceipt.diff(a, b)

      assert Map.has_key?(diff, :consequence_identity)
      assert diff.consequence_identity == {"consequence-1", "consequence-2"}
      refute Map.has_key?(diff, :predecessor_receipt)
      refute diff == %{}
    end

    test "detects a real divergence in stability_result between otherwise-identical receipts" do
      {:ok, a} = ProcessReceipt.new(base_fields(%{stability_result: "stable"}))
      {:ok, b} = ProcessReceipt.new(base_fields(%{stability_result: "unstable"}))

      diff = ProcessReceipt.diff(a, b)

      assert diff.stability_result == {"stable", "unstable"}
    end
  end
end
