defmodule Xaas.ActuationReceiptTamperTest do
  @moduledoc """
  Chicago-style adversarial "sabotage court" test for `Xaas.Actuation`'s replay path.

  Modeled on `ash_r2rml`'s adversarial suite pattern (prove a deliberately mutated
  artifact is *detected*, not just that the happy path passes) and directly
  instantiates this repo's own `no-overclaiming-conversational.md` rule: "construct
  one concrete, maximally adversarial example and run it."

  This mutates a real, sealed `Xaas.Operations.ActuationReceipt`'s `result_hash`
  directly (via its own real `:seal` Ash action, `authorize?: false` -- the same
  privileged path `Xaas.Actuation.Kernel.seal/2` itself uses, simulating a
  corrupted-at-rest write rather than out-of-band SQL) and then calls
  `Xaas.Actuation.run/4` again with the SAME idempotency key.

  CURRENT, VERIFIED BEHAVIOR (as of this commit): `Xaas.Actuation.Kernel.
  replay_or_refuse/4` (`lib/xaas/actuation.ex`) compares the new call's freshly
  computed `input_hash`/`ontology_projection_hash` against the stored
  `ActuationIntent`'s fields -- it never recomputes `result_hash` from the sealed
  `ActuationReceipt`'s own canonical payload and compares that recomputation
  against what is persisted. A receipt whose `result_hash` has been corrupted
  at rest is therefore replayed successfully, with the corrupted value handed
  back unexamined. This test asserts that CURRENT behavior honestly (a real,
  passing falsifier documenting a real, open gap) rather than silently
  asserting the safer behavior that does not yet exist -- flip this test's final
  assertion to `refute` (and add a recompute-and-compare step to
  `replay_or_refuse/4`) when that gap is closed.
  """

  use ExUnit.Case, async: true

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.ActuationReceipt

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_provider! do
    Provider
    |> Ash.Changeset.for_create(:create, %{
      name: "Tamper Provider",
      slug: "tamper-provider-#{System.unique_integer([:positive])}",
      org_id: "org-tamper"
    })
    |> Ash.create!(authorize?: false)
  end

  test "replay does not detect a receipt whose result_hash was corrupted at rest" do
    provider = create_provider!()
    key = "test-tamper-#{System.unique_integer([:positive])}"

    assert {:ok, first} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "actuation_receipt_tamper_test"}
             )

    real_result_hash = first.receipt.result_hash
    corrupted_result_hash = "corrupted-" <> real_result_hash

    assert {:ok, tampered_receipt} =
             Ash.update(first.receipt, %{result_hash: corrupted_result_hash},
               action: :seal,
               authorize?: false
             )

    assert tampered_receipt.result_hash == corrupted_result_hash
    refute tampered_receipt.result_hash == real_result_hash

    assert {:ok, replay} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "actuation_receipt_tamper_test"}
             )

    assert replay.status == :replayed
    assert replay.replay?

    persisted_receipt = Ash.get!(ActuationReceipt, tampered_receipt.id, authorize?: false)

    # KNOWN GAP (see moduledoc): the corrupted hash survives replay unexamined.
    assert persisted_receipt.result_hash == corrupted_result_hash
  end
end
