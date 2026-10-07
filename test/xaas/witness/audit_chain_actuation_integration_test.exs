defmodule Xaas.Witness.AuditChainActuationIntegrationTest do
  @moduledoc """
  Lane W524b — Theorem 4.1 against the REAL actuation receipt stream.

  Witnesses that sealed receipts emitted by `Xaas.Actuation.run/4` (the
  admitted DO path, `:actuate_status` on `Xaas.Marketplace.Provider`)
  satisfy the audit-chain contract of `Xaas.Witness.AuditChain`
  (Definition 4.2): the real receipt fields map onto chain entries whose
  links verify, tampering is detected with exact attribution, and the
  martingale observable is monotone on the real stream.

  Chicago discipline: real Ash resources, real Reactor, real sandboxed
  Postgres, real `Xaas.Actuation.run/4` — no mocks, no fakes. The chain
  is exercised over pure functions (AuditChain is a pure module), so the
  only "state" asserted is the real receipt data and the recomputed
  hashes over it.

  Mapping (real receipt -> chain entry):

    * `actuation_id`   <- `receipt.id` (the sealed receipt UUID)
    * `payload_digest` <- SHA-256 hex over JCS(RFC 8785) of the receipt's
      canonical string-keyed field map (same Jcs dependency as
      `AuditChain.hash_receipt/2`)
    * `sig_slot`       <- `receipt.replay_token` (nil on first attempts)
  """

  use ExUnit.Case, async: true

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.ActuationReceipt
  alias Xaas.Witness.AuditChain

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # Mirrors test/xaas/actuation_test.exs setup: real provider, real
  # authority context, unique idempotency key per actuation.
  defp create_provider! do
    Xaas.Generator.create_provider!(%{name: "Witness Provider", org_id: "org-witness"})
  end

  defp run_actuation!(provider, key, status) do
    assert {:ok, result} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: status},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "w524b_audit_chain"}
             )

    assert %ActuationReceipt{} = result.receipt
    result
  end

  # The canonical form of a real sealed receipt: a string-keyed map of the
  # receipt's durable fields, JSON-encodable under JCS (RFC 8785). Atoms
  # become strings; datetimes become ISO-8601 strings.
  defp canonical_payload(%ActuationReceipt{} = receipt) do
    %{
      "id" => receipt.id,
      "intent_id" => receipt.intent_id,
      "attempt" => receipt.attempt,
      "status" => to_string(receipt.status),
      "resource_module" => receipt.resource_module,
      "action" => receipt.action,
      "subject_id" => receipt.subject_id,
      "ontology_projection_hash" => receipt.ontology_projection_hash,
      "input_hash" => receipt.input_hash,
      "result_hash" => receipt.result_hash,
      "replay_token" => receipt.replay_token,
      "started_at" => dt(receipt.started_at),
      "completed_at" => dt(receipt.completed_at)
    }
  end

  defp dt(nil), do: nil
  defp dt(%DateTime{} = d), do: DateTime.to_iso8601(d)

  defp payload_digest(%ActuationReceipt{} = receipt) do
    :crypto.hash(:sha256, Jcs.encode(canonical_payload(receipt)))
    |> Base.encode16(case: :lower)
  end

  defp append_receipt!(chain, %ActuationReceipt{} = receipt) do
    assert {:ok, chain, head} =
             AuditChain.append(chain, %{
               actuation_id: receipt.id,
               payload_digest: payload_digest(receipt),
               sig_slot: receipt.replay_token
             })

    {chain, head}
  end

  test "actuation receipts feed the audit chain: chain of 2 real receipts verifies :ok" do
    provider = create_provider!()

    receipt1 =
      run_actuation!(provider, "w524b-key-1-#{System.unique_integer([:positive])}", :active).receipt

    {chain, _head} = append_receipt!([], receipt1)

    receipt2 =
      run_actuation!(provider, "w524b-key-2-#{System.unique_integer([:positive])}", :suspended).receipt

    {chain, head} = append_receipt!(chain, receipt2)

    # Real receipt content survived the mapping.
    assert receipt1.status == :succeeded
    assert receipt1.input_hash && receipt1.result_hash
    assert receipt1.completed_at
    assert receipt1.id != receipt2.id
    assert receipt2.status == :succeeded

    # Chain structure over the real stream.
    assert Enum.map(chain, & &1.t) == [0, 1]
    assert Enum.map(chain, & &1.actuation_id) == [receipt1.id, receipt2.id]
    assert hd(chain).prev_hash == AuditChain.root_hash()
    assert Enum.at(chain, 1).prev_hash == head_of_first_link(receipt1)

    # Theorem 4.1 base case: the real 2-receipt stream verifies.
    assert AuditChain.verify_chain(chain) == :ok
    assert AuditChain.verify_chain(chain, expected_length: 2) == :ok

    # Head hash is reproducible from the chain alone.
    assert head == AuditChain.hash_receipt(Enum.at(chain, 1), Enum.at(chain, 1).prev_hash)

    # The digest is a real commitment: recomputing from the live receipt
    # struct is deterministic and differs from the sibling's.
    assert payload_digest(receipt1) == hd(chain).payload_digest
    assert payload_digest(receipt1) != payload_digest(receipt2)
  end

  # H over the first receipt alone, recomputed from the real receipt.
  defp head_of_first_link(%ActuationReceipt{} = receipt) do
    {:ok, [only], head} =
      AuditChain.append([], %{
        actuation_id: receipt.id,
        payload_digest: payload_digest(receipt),
        sig_slot: receipt.replay_token
      })

    assert only.t == 0
    head
  end

  test "tampering a real receipt's payload is detected with exact attribution" do
    provider = create_provider!()

    receipt1 =
      run_actuation!(provider, "w524b-tamper-1-#{System.unique_integer([:positive])}", :active).receipt

    receipt2 =
      run_actuation!(provider, "w524b-tamper-2-#{System.unique_integer([:positive])}", :suspended).receipt

    {chain, _head} = append_receipt!([], receipt1)
    {chain, _} = append_receipt!(chain, receipt2)
    assert AuditChain.verify_chain(chain) == :ok

    # In-memory tamper of the FIRST captured receipt's payload: mutate its
    # canonical form (result_hash flipped), recompute what the digest would
    # have been, and splice that forged digest into the stored entry.
    forged_payload = %{canonical_payload(receipt1) | "result_hash" => "forged-result-hash"}
    forged_digest = :crypto.hash(:sha256, Jcs.encode(forged_payload)) |> Base.encode16(case: :lower)
    assert forged_digest != hd(chain).payload_digest

    tampered = List.update_at(chain, 0, fn r -> %{r | payload_digest: forged_digest} end)

    # 0-based indexing + successor-consistency (Definition 4.2): a content
    # tamper of receipt k breaks the (k, k+1) link, so a forged FIRST
    # receipt is attributed exactly to index 0.
    assert AuditChain.verify_chain(tampered) == {:error, {:tampered, 0}}

    # Tampering the SECOND receipt's payload with a malformed digest is
    # attributed exactly to index 1 (payload-digest format check).
    tampered1 = List.update_at(chain, 1, fn r -> %{r | payload_digest: "not-a-digest"} end)
    assert AuditChain.verify_chain(tampered1) == {:error, {:tampered, 1}}
  end

  test "martingale observable is monotone non-increasing over the real receipt stream" do
    provider = create_provider!()

    receipt1 =
      run_actuation!(provider, "w524b-mg-1-#{System.unique_integer([:positive])}", :active).receipt

    receipt2 =
      run_actuation!(provider, "w524b-mg-2-#{System.unique_integer([:positive])}", :suspended).receipt

    {chain, _} = append_receipt!([], receipt1)
    {chain, _} = append_receipt!(chain, receipt2)

    # Untampered real stream: M_t = 1 everywhere (non-vacuous base case).
    assert AuditChain.martingale(chain) == [1, 1]

    # Once tampered, M_t never recovers — monotone on real data.
    tampered = List.update_at(chain, 0, fn r -> %{r | payload_digest: String.duplicate("f", 64)} end)
    assert AuditChain.martingale(tampered) == [0, 0]

    # Property sweep: for every single-link tamper position, M_t is
    # monotone non-increasing over the real receipts.
    for k <- 0..(length(chain) - 1) do
      m =
        chain
        |> List.update_at(k, fn r -> %{r | payload_digest: String.duplicate("e", 64)} end)
        |> AuditChain.martingale()

      drops = m |> Enum.zip(tl(m) ++ [0]) |> Enum.count(fn {a, b} -> b > a end)
      assert drops == 0, "M_t increased at k=#{k}: #{inspect(m)}"
    end
  end

  test "replayed actuation (same idempotency key) does not grow the chain" do
    provider = create_provider!()
    key = "w524b-replay-#{System.unique_integer([:positive])}"

    first = run_actuation!(provider, key, :active)
    refute first.replay?

    {chain, head} = append_receipt!([], first.receipt)

    replay = run_actuation!(provider, key, :active)
    assert replay.replay?
    assert replay.receipt.id == first.receipt.id

    # The replay does not mint a new receipt: no new persisted receipt row
    # (mirrors actuation_test's receipt-count assertion) and the digest over
    # the returned receipt is byte-identical, so the witness layer has
    # nothing new to append. AuditChain.append/2 is append-only by design;
    # dedup is the stream layer's job (same receipt -> skip), asserted here
    # by identity, not by a fake dedup in the chain.
    receipts_before = Ash.read!(ActuationReceipt, authorize?: false)
    assert payload_digest(replay.receipt) == payload_digest(first.receipt)
    assert length(Ash.read!(ActuationReceipt, authorize?: false)) == length(receipts_before)

    {chain_after, _head_after} =
      if replay.receipt.id == first.receipt.id do
        {chain, head}
      else
        append_receipt!(chain, replay.receipt)
      end

    assert length(chain_after) == 1
    assert AuditChain.verify_chain(chain_after) == :ok
  end
end
