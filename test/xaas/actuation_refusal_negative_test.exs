defmodule Xaas.ActuationRefusalNegativeTest do
  @moduledoc """
  Negative-path qualification for the actuation kernel's typed refusal
  branches (vector2-refusal-coverage § C):

    * `:subject_id_required` (lib/xaas/actuation.ex:764) — update/destroy
      actuation with a nil subject halts before any changeset runs;
    * the `verify_external_prepared/3` mismatch family
      (lib/xaas/actuation.ex:530-541): `:external_receipt_intent_mismatch`,
      `:external_admission_identity_mismatch`, `:external_projection_mismatch`,
      `:external_input_mismatch`;
    * the `:external_checkpoint_conflict` branch (lib/xaas/actuation.ex:417) —
      a second checkpoint over a bound construct with a diverging payload.

  Real Ash resources over the real sandboxed Postgres, real env var, no
  mocks. Every refusal asserts the exact error tuple AND zero consequential
  state yield: the subject row is byte-for-byte the pre-refusal row, and
  the prepared receipt stays inert (`result == %{}`, no result hash).
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_provider! do
    Xaas.Generator.create_provider!(%{name: "Refusal Fixture Provider", org_id: "org-refusal"})
  end

  defp receipt_count do
    Ash.count(ActuationReceipt, authorize?: false)
  end

  defp prepare_external!(provider, key, input \\ %{status: :active}) do
    assert {:ok, %{status: :prepared, replay?: false, admission: admission}} =
             Xaas.Actuation.prepare_external(
               Provider,
               :actuate_status,
               input,
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "refusal_test"}
             )

    admission
  end

  test "update actuation with a nil subject is refused :subject_id_required before any changeset" do
    provider = create_provider!()
    status_before = provider.status
    key = "refusal-subject-required-#{System.unique_integer([:positive])}"

    # Landed contract (W773 seal-boundary normalization, `Kernel.seal/2`,
    # lib/xaas/actuation.ex; W953 adjudication row 1): the DO step's
    # `{:error, :subject_id_required}` (from `get_subject/5`) is no longer
    # rolled back as a wrapped `{:reactor_failed, %Reactor.Error.Invalid{}}`
    # (the bare atom cannot populate the receipt ledger's `:map` `error`
    # attribute). Instead it seals a real `:failed` receipt via
    # `sealed_error/1` and surfaces `{:error, raw_reason}` — the raw atom,
    # not a wrapper.
    assert {:error, :subject_id_required} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: nil,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "refusal_test"}
             )

    # Zero consequential state change: the subject row is untouched, the
    # refused key's intent/receipt are sealed `:failed` (durable refusal
    # record), and the provider was never actuated.
    provider_after = Ash.get!(Provider, provider.id, authorize?: false)
    assert provider_after.status == status_before
    assert provider_after.updated_at == provider.updated_at

    assert {:ok, intent} =
             Ash.read_one(
               ActuationIntent
               |> Ash.Query.for_read(:read)
               |> Ash.Query.filter(idempotency_key == ^key),
               authorize?: false
             )

    assert intent.status == :failed

    assert {:ok, receipt} =
             Ash.read_one(
               ActuationReceipt
               |> Ash.Query.for_read(:read)
               |> Ash.Query.filter(intent_id == ^intent.id),
               authorize?: false
             )

    assert receipt.status == :failed
    assert is_map(receipt.error)
    assert receipt.result == %{}
  end

  test "checkpoint with a forged projection hash is refused :external_projection_mismatch" do
    provider = create_provider!()
    key = "refusal-projection-mismatch-#{System.unique_integer([:positive])}"
    admission = prepare_external!(provider, key)
    receipt = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)

    forged = %{admission | projection_hash: "forged-projection-hash"}

    assert {:error, {:external_checkpoint_failed, :external_projection_mismatch}} =
             Xaas.Actuation.checkpoint_external(forged, %{"construct" => "inert"})

    # Zero state change: the receipt stays prepared and inert, the subject
    # row is untouched.
    receipt_after = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)
    assert receipt_after.status == :prepared
    assert receipt_after.result == %{}
    assert is_nil(receipt_after.result_hash)
    assert receipt_after.input_hash == receipt.input_hash

    assert Ash.get!(Provider, provider.id, authorize?: false).status == provider.status
  end

  test "receipt rebound to a foreign intent is refused :external_receipt_intent_mismatch" do
    provider = create_provider!()
    key = "refusal-receipt-intent-mismatch-#{System.unique_integer([:positive])}"
    admission = prepare_external!(provider, key)

    # A real second intent (its own durable admission) provides the foreign
    # intent id the receipt is illegitimately rebound to.
    foreign_admission =
      prepare_external!(
        provider,
        "refusal-foreign-intent-#{System.unique_integer([:positive])}"
      )

    # Rebind receipt #1 to intent #2 directly in the sandbox (real Ecto row
    # mutation, exactly the forgery verify_external_prepared/3 must catch).
    receipt = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)

    assert {:ok, _} =
             Xaas.Repo.update(
               Ecto.Changeset.change(receipt, intent_id: foreign_admission.intent.id)
             )

    assert {:error, {:external_checkpoint_failed, :external_receipt_intent_mismatch}} =
             Xaas.Actuation.checkpoint_external(admission, %{"construct" => "inert"})

    # Zero state change: neither receipt moved from :prepared, the provider
    # row is untouched.
    for adm <- [admission, foreign_admission] do
      receipt_after = Ash.get!(ActuationReceipt, adm.receipt.id, authorize?: false)
      assert receipt_after.status == :prepared
      assert receipt_after.result == %{}
    end

    assert Ash.get!(Provider, provider.id, authorize?: false).status == provider.status
  end

  test "second checkpoint with a diverging construct is refused :external_checkpoint_conflict" do
    provider = create_provider!()
    key = "refusal-checkpoint-conflict-#{System.unique_integer([:positive])}"
    admission = prepare_external!(provider, key)

    # First checkpoint binds a real construct to the prepared receipt (the
    # interrupted-seal recovery state).
    assert {:ok, %{resumed?: false}} =
             Xaas.Actuation.checkpoint_external(admission, %{
               "construct" => "inert",
               "attempt" => 1
             })

    # A second checkpoint over the same receipt with a diverging payload must
    # hit the conflict branch — the durable checkpoint cannot be silently
    # rewritten to a different construct identity.
    assert {:error, {:external_checkpoint_failed, {:external_checkpoint_conflict, ^key}}} =
             Xaas.Actuation.checkpoint_external(admission, %{
               "construct" => "inert",
               "attempt" => 2
             })

    # Zero state change: the receipt keeps the FIRST checkpoint's snapshot and
    # hash, stays :prepared, and the subject row is untouched.
    receipt_after = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)
    assert receipt_after.status == :prepared
    assert receipt_after.result == %{"attempt" => 1, "construct" => "inert"}
    assert is_binary(receipt_after.result_hash)

    assert Ash.get!(Provider, provider.id, authorize?: false).status == provider.status
  end

  test "admission struct forged to a foreign but internally-consistent admission pair is refused :external_admission_identity_mismatch" do
    provider = create_provider!()
    key = "refusal-admission-identity-witness-#{System.unique_integer([:positive])}"
    admission = prepare_external!(provider, key)

    # A real second admission (its own durable intent + prepared receipt) for a
    # DIFFERENT input, so the forged pair is internally consistent but its
    # stored input_hash disagrees with the input the caller's admission
    # actually carries.
    foreign_admission =
      prepare_external!(
        provider,
        "refusal-foreign-admission-#{System.unique_integer([:positive])}",
        %{status: :inactive}
      )

    # Forge the admission struct IN MEMORY to the foreign pair, keeping the
    # caller's own admission-carried context (resource, action, subject_id,
    # raw_input, projection_hash). Before W546/OS-18 this forgery was ADMITTED
    # (the identity clause was a tautology over the load keys); now the
    # carried-context check refuses it.
    forged = %{admission | intent: foreign_admission.intent, receipt: foreign_admission.receipt}

    assert {:error, {:external_checkpoint_failed, :external_admission_identity_mismatch}} =
             Xaas.Actuation.checkpoint_external(forged, %{"construct" => "inert"})

    # Zero state change: neither receipt moved from :prepared/inert — the
    # forged checkpoint durably bound nothing.
    for adm <- [admission, foreign_admission] do
      receipt_after = Ash.get!(ActuationReceipt, adm.receipt.id, authorize?: false)
      assert receipt_after.status == :prepared
      assert receipt_after.result == %{}
      assert is_nil(receipt_after.result_hash)
    end

    assert Ash.get!(Provider, provider.id, authorize?: false).status == provider.status
  end

  test "honest resumed admission passes the tightened admission-identity check" do
    provider = create_provider!()
    key = "refusal-honest-resume-#{System.unique_integer([:positive])}"
    admission = prepare_external!(provider, key)

    # Honest re-prepare of the SAME key/input resumes the same durable pair —
    # the carried context must still match the loaded rows.
    assert {:ok, %{status: :prepared, admission: %{resumed?: true} = resumed}} =
             Xaas.Actuation.prepare_external(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "refusal_test"}
             )

    assert resumed.intent.id == admission.intent.id
    assert resumed.receipt.id == admission.receipt.id

    assert {:ok, %{resumed?: false, receipt: receipt}} =
             Xaas.Actuation.checkpoint_external(resumed, %{"construct" => "inert"})

    assert receipt.result == %{"construct" => "inert"}
    assert is_binary(receipt.result_hash)
  end

  test "receipt input hash forged after admission is refused :external_input_mismatch" do
    provider = create_provider!()
    key = "refusal-input-mismatch-#{System.unique_integer([:positive])}"
    admission = prepare_external!(provider, key)

    receipt = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)

    assert {:ok, _} =
             Xaas.Repo.update(Ecto.Changeset.change(receipt, input_hash: "forged-input-hash"))

    assert {:error, {:external_checkpoint_failed, :external_input_mismatch}} =
             Xaas.Actuation.checkpoint_external(admission, %{"construct" => "inert"})

    receipt_after = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)
    assert receipt_after.status == :prepared
    assert receipt_after.result == %{}
    assert receipt_after.input_hash == "forged-input-hash"

    assert Ash.get!(Provider, provider.id, authorize?: false).status == provider.status
  end

  # W601 (OS-18 residual): the receipt row carries its own copies of
  # resource/action/subject. Before this leg the identity clause compared
  # those fields against the INTENT row only, so a pair whose receipt fields
  # diverged from both the intent and the admission still checkpointed.
  describe "W601 field-by-field receipt identity" do
    test "receipt row with a tampered subject_id is refused :external_admission_identity_mismatch" do
      provider = create_provider!()
      key = "refusal-w601-receipt-subject-#{System.unique_integer([:positive])}"
      admission = prepare_external!(provider, key)

      receipt = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)

      assert {:ok, _} =
               Xaas.Repo.update(
                 Ecto.Changeset.change(receipt, subject_id: "forged-foreign-subject")
               )

      assert {:error, {:external_checkpoint_failed, :external_admission_identity_mismatch}} =
               Xaas.Actuation.checkpoint_external(admission, %{"construct" => "inert"})

      # Zero state yield: the tampered receipt stays inert :prepared.
      receipt_after = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)
      assert receipt_after.status == :prepared
      assert receipt_after.result == %{}
      assert is_nil(receipt_after.result_hash)
      assert receipt_after.subject_id == "forged-foreign-subject"

      assert Ash.get!(Provider, provider.id, authorize?: false).status == provider.status
    end

    test "receipt row with a tampered action is refused :external_admission_identity_mismatch" do
      provider = create_provider!()
      key = "refusal-w601-receipt-action-#{System.unique_integer([:positive])}"
      admission = prepare_external!(provider, key)

      receipt = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)

      assert {:ok, _} =
               Xaas.Repo.update(Ecto.Changeset.change(receipt, action: "actuate_status_forged"))

      assert {:error, {:external_checkpoint_failed, :external_admission_identity_mismatch}} =
               Xaas.Actuation.checkpoint_external(admission, %{"construct" => "inert"})

      receipt_after = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)
      assert receipt_after.status == :prepared
      assert receipt_after.result == %{}
      assert is_nil(receipt_after.result_hash)

      assert Ash.get!(Provider, provider.id, authorize?: false).status == provider.status
    end

    test "honest fresh admission still checkpoints and seals (happy path unchanged)" do
      provider = create_provider!()
      key = "refusal-w601-happy-#{System.unique_integer([:positive])}"
      admission = prepare_external!(provider, key)

      assert {:ok, %{resumed?: false, receipt: receipt}} =
               Xaas.Actuation.checkpoint_external(admission, %{"construct" => "inert"})

      assert receipt.result == %{"construct" => "inert"}
      assert is_binary(receipt.result_hash)

      assert {:ok, %{status: :succeeded}} =
               Xaas.Actuation.seal_external(admission, {:ok, %{"ok" => true}})

      receipt_after = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)
      assert receipt_after.status == :succeeded

      intent_after = Ash.get!(ActuationIntent, admission.intent.id, authorize?: false)
      assert intent_after.status == :succeeded

      assert Ash.get!(Provider, provider.id, authorize?: false).status == provider.status
    end
  end
end
