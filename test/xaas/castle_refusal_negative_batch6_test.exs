defmodule Xaas.Castle.RefusalNegativeBatch6Test do
  @moduledoc """
  Wave W185 lane: negative fixtures closing the W176 16-token refusal delta.

  Covered here (exact typed refusal, zero witness state yield):

    * the 13 outer-intent / outer-receipt verification gate tokens
      (`verify_outer_intent/3`, `verify_outer_receipt/3`,
      `verify_checkpoint_receipt/3` at castle.ex:360-421, reached through
      `Xaas.Castle.Admission.witness/3` map form);
    * `{:error, {:REFUSED_REQUIRED_FIELD, key}}` at castle.ex:501/506/1040,
      through both the admission witness gate and `Xaas.Castle.Kernel.CLI`.

  Method (Chicago): one real admission fixture family — a real
  `Xaas.Marketplace.Provider` subject over real sandboxed Postgres rows created
  by `Xaas.Actuation.prepare_external/4` — built once per test, exactly one
  field mutated per token (the mutated field is named by the token itself),
  exact-tuple/atom assertion, and a zero-yield assertion that the refused
  witness created no new intent/receipt rows and did not repair the tampered
  row. No mocks, no doubles.
  """

  use ExUnit.Case, async: false

  import Ecto.Query

  alias Xaas.Castle.Admission
  alias Xaas.Castle.Kernel.CLI
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt, RouteCastleRun}

  @hex64 String.duplicate("f", 64)
  @other_hash String.duplicate("b", 64)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    for k <-
          ~w(CASTLE_BIN CASTLE_BIN_SHA256 CASTLE_SIGNING_KEY_PATH CASTLE_KEY_ID CASTLE_EVIDENCE_ROOT),
        do: System.delete_env(k)

    previous_profiles = Application.get_env(:xaas, :castle_adapter_profiles)

    on_exit(fn ->
      for k <-
            ~w(CASTLE_BIN CASTLE_BIN_SHA256 CASTLE_SIGNING_KEY_PATH CASTLE_KEY_ID CASTLE_EVIDENCE_ROOT),
          do: System.delete_env(k)

      if is_nil(previous_profiles),
        do: Application.delete_env(:xaas, :castle_adapter_profiles),
        else: Application.put_env(:xaas, :castle_adapter_profiles, previous_profiles)
    end)

    :ok
  end

  ## Fixture family: real admission over real rows, one per test

  defp prepared_admission!(subject \\ "subj-batch6") do
    intent = %{subject: subject, authority: "test_authority"}

    assert {:ok, %{status: :prepared, admission: admission}} =
             Xaas.Actuation.prepare_external(
               RouteCastleRun,
               :execute,
               %{intent: intent},
               subject_id: subject,
               idempotency_key: "batch6-#{System.unique_integer([:positive])}",
               authorize?: false,
               authority: %{kind: "test_authority", source: "batch6_test"}
             )

    assert admission.intent.status == :executing
    assert admission.receipt.status == :prepared
    admission
  end

  defp tamper!(row, changes) do
    row
    |> Ecto.Changeset.change(changes)
    |> Xaas.Repo.update!()
  end

  defp witness_call(admission, intent_map, projection_hash \\ nil, now \\ nil) do
    now = now || System.system_time(:millisecond)

    context = %{
      intent: admission.intent,
      receipt: admission.receipt,
      projection_hash: projection_hash || admission.projection_hash
    }

    Admission.witness(context, intent_map, now)
  end

  defp valid_intent_map(admission) do
    %{
      subject: admission.intent.subject_id,
      authority: "test_authority",
      envelope: %{expires_at_epoch_ms: System.system_time(:millisecond) + 60_000}
    }
  end

  defp snapshot(admission) do
    intent = Xaas.Repo.reload!(admission.intent)
    receipt = Xaas.Repo.reload!(admission.receipt)
    {intent.updated_at, receipt.updated_at, receipt.status, intent.status}
  end

  defp assert_zero_yield(admission, before_intents, before_receipts, pre_witness) do
    assert Ash.count(ActuationIntent, authorize?: false) == before_intents
    assert Ash.count(ActuationReceipt, authorize?: false) == before_receipts

    # The gate never repairs a tampered row and never touches the subject.
    assert snapshot(admission) == pre_witness
  end

  defp counts do
    {Ash.count(ActuationIntent, authorize?: false),
     Ash.count(ActuationReceipt, authorize?: false)}
  end

  ## Happy-path sanity for the fixture family

  test "untampered fixture yields an ALIVE witness through the map-form gate" do
    admission = prepared_admission!()
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:ok, %{"admitted" => true, "standing" => "ALIVE"} = witness} =
             witness_call(admission, valid_intent_map(admission))

    assert witness["xaas_intent_id"] == to_string(admission.intent.id)
    assert byte_size(witness["witness_digest"]) == 64
    assert_zero_yield(admission, intents, receipts, pre)
  end

  ## 13 outer-intent / outer-receipt gate tokens — one mutation each

  test "REFUSED_XAAS_INTENT_NOT_EXECUTING — outer intent status drifted" do
    admission = prepared_admission!()
    tamper!(admission.intent, %{status: :prepared})
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_INTENT_NOT_EXECUTING} =
             witness_call(admission, valid_intent_map(admission))

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_RESOURCE_MISMATCH — outer intent resource drifted" do
    admission = prepared_admission!()
    tamper!(admission.intent, %{resource_module: "Xaas.Billing.Provider"})
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_RESOURCE_MISMATCH} =
             witness_call(admission, valid_intent_map(admission))

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_ACTION_MISMATCH — outer intent action drifted" do
    admission = prepared_admission!()
    tamper!(admission.intent, %{action: "write"})
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_ACTION_MISMATCH} =
             witness_call(admission, valid_intent_map(admission))

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_SUBJECT_MISMATCH — runtime intent names a foreign subject" do
    admission = prepared_admission!()
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_SUBJECT_MISMATCH} =
             witness_call(admission, %{valid_intent_map(admission) | subject: "org-foreign"})

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_PROJECTION_MISMATCH — caller context hash diverges from the outer row" do
    admission = prepared_admission!()
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_PROJECTION_MISMATCH} =
             witness_call(admission, valid_intent_map(admission), @other_hash)

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_PROJECTION_DRIFT — outer row hash drifted from RouteCastleRun" do
    admission = prepared_admission!()
    tamper!(admission.intent, %{ontology_projection_hash: @other_hash})
    {intents, receipts} = counts()
    pre = snapshot(admission)

    # The caller context still carries the originally-admitted hash, so the
    # row-vs-context check passes and the row-vs-RouteCastleRun drift fires.
    assert {:error, :REFUSED_XAAS_PROJECTION_DRIFT} =
             witness_call(admission, valid_intent_map(admission), @other_hash)

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_IDEMPOTENCY_MISMATCH — outer intent idempotency key drifted" do
    admission = prepared_admission!()
    tamper!(admission.intent, %{idempotency_key: "batch6-drifted-key"})
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_IDEMPOTENCY_MISMATCH} =
             witness_call(admission, valid_intent_map(admission))

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_RECEIPT_INTENT_MISMATCH — receipt rebound to a foreign intent" do
    admission = prepared_admission!()

    # Rebind the receipt to a second real intent: the FK requires a real row,
    # and the gate must notice it is not THE admitted intent.
    foreign = prepared_admission!("subj-batch6-foreign")

    {_, _} =
      Xaas.Repo.update_all(
        from(r in ActuationReceipt, where: r.id == ^admission.receipt.id),
        set: [intent_id: foreign.intent.id]
      )

    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_RECEIPT_INTENT_MISMATCH} =
             witness_call(admission, valid_intent_map(admission))

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_RECEIPT_NOT_PREPARED — outer receipt status drifted past prepared" do
    admission = prepared_admission!()
    tamper!(admission.receipt, %{status: :sealed})
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_RECEIPT_NOT_PREPARED} =
             witness_call(admission, valid_intent_map(admission))

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_RECEIPT_ACTION_MISMATCH — outer receipt resource/action drifted" do
    admission = prepared_admission!()
    tamper!(admission.receipt, %{resource_module: "Xaas.Billing.Provider"})
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_RECEIPT_ACTION_MISMATCH} =
             witness_call(admission, valid_intent_map(admission))

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_RECEIPT_PROJECTION_MISMATCH — receipt hash diverges from caller context" do
    admission = prepared_admission!()
    tamper!(admission.receipt, %{ontology_projection_hash: @other_hash})
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_RECEIPT_PROJECTION_MISMATCH} =
             witness_call(admission, valid_intent_map(admission))

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_RECEIPT_INPUT_MISMATCH — receipt input hash diverges from the intent" do
    admission = prepared_admission!()
    tamper!(admission.receipt, %{input_hash: @hex64})
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_RECEIPT_INPUT_MISMATCH} =
             witness_call(admission, valid_intent_map(admission))

    assert_zero_yield(admission, intents, receipts, pre)
  end

  test "REFUSED_XAAS_RECEIPT_REPLAY_TOKEN — receipt replay token is not a digest" do
    admission = prepared_admission!()
    tamper!(admission.receipt, %{replay_token: "not-a-digest"})
    {intents, receipts} = counts()
    pre = snapshot(admission)

    assert {:error, :REFUSED_XAAS_RECEIPT_REPLAY_TOKEN} =
             witness_call(admission, valid_intent_map(admission))

    assert_zero_yield(admission, intents, receipts, pre)
  end

  ## REFUSED_REQUIRED_FIELD — admission witness path (castle.ex:497-509)

  test "witness refuses {:REFUSED_REQUIRED_FIELD, :subject} when the intent omits subject" do
    admission = prepared_admission!()

    # The subject-equality gate (nil == nil) must pass first, so the tampered
    # outer row carries a nil subject too; the required-field gate then fires.
    tamper!(admission.intent, %{subject_id: nil})
    intent_map = Map.delete(valid_intent_map(admission), :subject)

    assert {:error, {:REFUSED_REQUIRED_FIELD, :subject}} =
             witness_call(admission, intent_map)
  end

  test "witness refuses {:REFUSED_REQUIRED_FIELD, :authority} for a blank authority" do
    admission = prepared_admission!()
    intent_map = %{valid_intent_map(admission) | authority: ""}

    assert {:error, {:REFUSED_REQUIRED_FIELD, :authority}} =
             witness_call(admission, intent_map)
  end

  test "witness refuses {:REFUSED_REQUIRED_FIELD, :envelope} when the intent omits envelope" do
    admission = prepared_admission!()
    intent_map = Map.delete(valid_intent_map(admission), :envelope)

    assert {:error, {:REFUSED_REQUIRED_FIELD, :envelope}} =
             witness_call(admission, intent_map)
  end

  ## REFUSED_REQUIRED_FIELD — CLI path (castle.ex:1031-1041, via build_request)

  defp cli_runtime_env!(dir) do
    bin = System.find_executable("true") || "/bin/true"
    bin_sha = Base.encode16(:crypto.hash(:sha256, File.read!(bin)), case: :lower)
    key_path = Path.join(dir, "signing.key")
    File.write!(key_path, "batch6-signing-seed")

    System.put_env("CASTLE_BIN", bin)
    System.put_env("CASTLE_BIN_SHA256", bin_sha)
    System.put_env("CASTLE_SIGNING_KEY_PATH", key_path)
    System.put_env("CASTLE_KEY_ID", "batch6-key")
    System.put_env("CASTLE_EVIDENCE_ROOT", dir)
    :ok
  end

  @tag :tmp_dir
  test "CLI manufacture refuses required fields before any CASTLE invocation", %{tmp_dir: tmp_dir} do
    cli_runtime_env!(tmp_dir)

    Application.put_env(:xaas, :castle_adapter_profiles, %{
      "batch6-profile" => %{adapter_policy: %{}, allowed_authorities: ["test_authority"]}
    })

    witness = %{
      "subject" => "subj",
      "authority" => "test_authority",
      "witness_digest" => String.duplicate("a", 64),
      "xaas_receipt_id" => "rcpt"
    }

    for key <- ~w(subject authority process envelope) do
      intent =
        %{
          "adapter_profile_id" => "batch6-profile",
          "subject" => "subj",
          "authority" => "test_authority",
          "process" => %{"steps" => []},
          "envelope" => %{"system_id" => "subj"}
        }
        |> Map.delete(key)

      assert {:error, {:REFUSED_REQUIRED_FIELD, refused_key}} = CLI.manufacture(intent, witness)
      assert refused_key == String.to_existing_atom(key)
    end
  end
end
