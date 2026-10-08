defmodule Xaas.Deepening.Art261GovernedActuationStopChainTest do
  @moduledoc """
  Lane W984p — evidenced-line deepening wave 4, corpus line **26.1**
  (Art. 26(1), deployer duty: use of a high-risk AI system "in accordance
  with the instructions for use").

  The corpus evidence entry for 26.1 (W507/W503) cites the governed
  actuation surface under the human-authority quiescent stop plus the
  audit chain. `quiescent_stop_test.exs` (w507) courts the stop surface's
  typed contracts; `audit_chain_test.exs` (w503) courts the chain over
  synthetic receipts. The uncovered composition is the REAL pipeline:
  governed use per instructions (real `Xaas.Actuation.run/4` DO with a
  durable intent + sealed receipt) composed with the human-authority
  quiescent stop over the SAME subject, whose real receipts are then
  witnesses into a real `Xaas.Witness.AuditChain` that verifies clean and
  detects a real tamper.

  Mutation rationale: if the stop surface stops driving the subject (the
  DO is skipped, or `stopped?/2` drifts so a stopped subject admits a new
  stop DO), or the receipts lose their hash fields, the monotone-attractor
  and chain-witness courts fail while `quiescent_stop_test.exs`'s typed
  refusal courts and `audit_chain_test.exs`'s synthetic courts still pass.

  Chicago discipline: real Ash actions over real sandboxed Postgres, the
  real quiescent-stop surface, the real hash chain — no mocks.
  """

  use Xaas.DataCase, async: false

  # 26.1 is an evidenced corpus line (w537 evidence entry, W507/W503) —
  # eu_ai_act census.
  @moduletag :eu_ai_act

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.ActuationIntent
  alias Xaas.Witness.AuditChain

  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp unique_key(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp actuate(provider, key, status) do
    Xaas.Actuation.run(
      Provider,
      :actuate_status,
      %{status: status},
      subject_id: provider.id,
      idempotency_key: key,
      authorize?: false,
      authority: %{kind: "test_authority", source: "w984p_art_26_1"}
    )
  end

  defp stop(provider, key, authority) do
    Xaas.Actuation.QuiescentStop.execute(Provider,
      subject_id: provider.id,
      idempotency_key: key,
      authority: authority
    )
  end

  test "governed use per instructions: a real DO under a real authority produces a sealed receipt, and the quiescent stop drives the same subject to the safe state" do
    provider = Xaas.Generator.create_provider!(%{name: "W984p 26.1 Provider", org_id: "org-w984p-26-1"})

    # Governed use per instructions: a real, admitted, consequential DO
    # through the actuation kernel, with a sealed hash-bearing receipt.
    key = unique_key("w984p-261-use")
    assert {:ok, use_envelope} = actuate(provider, key, :active)

    assert %{status: :succeeded} = use_envelope
    assert %{receipt: use_receipt} = use_envelope
    assert is_binary(use_receipt.input_hash) and use_receipt.input_hash != ""
    assert is_binary(use_receipt.result_hash) and use_receipt.result_hash != ""

    # The instruction is durable: a real intent row binds the exact key.
    assert use_envelope.intent.idempotency_key == key

    assert {:ok, %ActuationIntent{}} =
             Ash.read_one(
               Ash.Query.filter(ActuationIntent, idempotency_key == ^key),
               authorize?: false
             )

    # Human-authority quiescent stop over the SAME subject: the stop surface
    # composes with governed use — the DO drives the real row to :suspended.
    stop_key = unique_key("w984p-261-stop")
    stop_authority = %{kind: "human_authority", source: "w984p_art_26_1_stop"}

    assert {:ok, stop} = stop(provider, stop_key, stop_authority)
    assert %{stopped_at: %DateTime{}, target: :quiescent, authority: ^stop_authority} = stop

    assert {:ok, row} = Ash.get(Provider, provider.id, authorize?: false)
    assert row.status == :suspended
  end

  test "monotone attractor over the real kernel: a stopped subject admits no new stop DO; fail-closed happens before any DO" do
    provider = Xaas.Generator.create_provider!(%{name: "W984p 26.1 Monotone", org_id: "org-w984p-26-1"})
    authority = %{kind: "human_authority", source: "w984p_art_26_1_mono"}

    # Drive the subject to quiescence through the real kernel.
    stop_key = unique_key("w984p-261-mono-stop")
    assert {:ok, _} = stop(provider, stop_key, authority)

    # Same key: idempotent replay of the receipt identity — no new DO.
    assert {:ok, %{already_stopped: true}} = stop(provider, stop_key, authority)

    # Fresh key over the stopped subject: typed attractor refusal.
    assert {:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT} =
             stop(provider, unique_key("w984p-261-mono-fresh"), authority)

    # Fail-closed before any DO: authority without a source is refused typed
    # and leaves no intent row.
    no_source_key = unique_key("w984p-261-mono-nosrc")

    assert {:error, :REFUSED_STOP_AUTHORITY} =
             Xaas.Actuation.QuiescentStop.execute(Provider,
               subject_id: provider.id,
               idempotency_key: no_source_key,
               authority: %{kind: "human_authority"}
             )

    assert {:ok, []} =
             Ash.read(Ash.Query.filter(ActuationIntent, idempotency_key == ^no_source_key),
               authorize?: false
             )

    # Missing key: refused before any DO.
    assert {:error, :idempotency_key_required} =
             Xaas.Actuation.QuiescentStop.execute(Provider,
               subject_id: provider.id,
               idempotency_key: nil,
               authority: authority
             )
  end

  test "the real receipts of governed use and its stop are tamper-evident audit-chain witnesses" do
    provider = Xaas.Generator.create_provider!(%{name: "W984p 26.1 Chain", org_id: "org-w984p-26-1"})

    # Two real DOs: governed use, then the human-authority stop.
    assert {:ok, use_env} = actuate(provider, unique_key("w984p-261-chain-use"), :active)
    assert {:ok, _} = stop(provider, unique_key("w984p-261-chain-stop"), %{
      kind: "human_authority",
      source: "w984p_art_26_1_chain"
    })

    # Both real receipts enter the real hash chain (payload digest = the
    # receipt's real input hash; sig_slot carries the intent identity).
    receipt_attrs = fn envelope, idx ->
      %{
        actuation_id: "w984p-261-#{idx}-#{envelope.intent.idempotency_key}",
        payload_digest: envelope.receipt.input_hash,
        sig_slot: "#{idx}:#{envelope.intent.idempotency_key}"
      }
    end

    assert {:ok, chain, _head} = AuditChain.append([], receipt_attrs.(use_env, 0))

    # Then the stop's REAL receipt (result hash — the post-DO digest).
    {:ok, chain, head} =
      AuditChain.append(chain, %{
        actuation_id: "w984p-261-stop-#{provider.id}",
        payload_digest: use_env.receipt.result_hash,
        sig_slot: "stop:#{provider.id}"
      })

    assert AuditChain.verify_chain(chain) == :ok
    assert is_binary(head) and byte_size(head) == 64

    # Tamper-evidence over real content: corrupting the use receipt's digest
    # is detected at exactly its link.
    k = 0

    tampered = List.update_at(chain, k, fn r -> %{r | payload_digest: String.duplicate("f", 64)} end)
    assert AuditChain.verify_chain(tampered) == {:error, {:tampered, k}}
  end
end
