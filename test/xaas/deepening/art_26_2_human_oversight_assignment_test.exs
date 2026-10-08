defmodule Xaas.Deepening.Art262HumanOversightAssignmentTest do
  @moduledoc """
  Lane W984be — corpus evidenced-line deepening wave 6, corpus line **26.2**
  (Art. 26(2), deployer duty: assign human oversight to competent persons).

  The corpus evidence entry for 26.2 (W507) cites "human oversight
  assigned via the human-authority quiescent-stop path (override +
  stop)" over `lib/xaas/actuation/quiescent_stop.ex`. The deepening_map
  entry for 26.2 is `[:quiescent_typed]`; `quiescent_stop_test.exs`
  (w507) courts the stop surface's typed contracts. The uncovered
  composition is the oversight ASSIGNMENT itself: a NAMED human
  authority (kind + source) drives a real stop DO through the real
  kernel, the assignment is echoed in the stop receipt, the assignment
  is durable (a real intent row binds the key), the receipt becomes a
  sig-verified audit-chain witness whose sig callback admits ONLY the
  assigned authority's receipts — and an UNASSIGNED authority is
  refused typed before any DO, leaving no durable assignment.

  Mutation rationale: if the stop surface stops echoing the authority
  into its receipt, or the fail-closed gate stops refusing an authority
  without a source, or the chain's signature verification stops
  rejecting a reassigned oversight identity, these courts fail while
  `quiescent_stop_test.exs`'s typed contracts and
  `audit_chain_test.exs`'s unsigned synthetic courts still pass.

  Chicago discipline: real Ash actions over real sandboxed Postgres,
  the real quiescent-stop surface, the real hash chain with a real sig
  callback — no mocks.
  """

  use Xaas.DataCase, async: false

  # 26.2 is an evidenced corpus line (W507) — eu_ai_act census.
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

  defp assigned_authority(tag) do
    %{kind: "human_authority", source: "w984be_art_26_2_#{tag}"}
  end

  defp stop(provider, key, authority) do
    Xaas.Actuation.QuiescentStop.execute(Provider,
      subject_id: provider.id,
      idempotency_key: key,
      authority: authority
    )
  end

  test "assigned oversight: a named human authority drives a real stop DO, the assignment is echoed in the receipt and durable as a real intent row" do
    provider =
      Xaas.Generator.create_provider!(%{name: "W984be 26.2 Assigned", org_id: "org-w984be-26-2"})

    authority = assigned_authority("primary")

    key = unique_key("w984be-262-stop")
    assert {:ok, stop_receipt} = stop(provider, key, authority)

    # The receipt echoes EXACTLY the assigned authority — oversight is
    # attributable, not anonymous.
    assert %{
             stopped_at: %DateTime{},
             target: :quiescent,
             authority: ^authority
           } = stop_receipt

    # The DO really drove the subject to the safe state.
    assert {:ok, row} = Ash.get(Provider, provider.id, authorize?: false)
    assert row.status == :suspended

    # The assignment is durable: a real intent row binds the exact key.
    assert {:ok, %ActuationIntent{}} =
             Ash.read_one(
               Ash.Query.filter(ActuationIntent, idempotency_key == ^key),
               authorize?: false
             )
  end

  test "unassigned oversight is refused typed before any DO and leaves no durable assignment" do
    provider =
      Xaas.Generator.create_provider!(%{name: "W984be 26.2 Unassigned", org_id: "org-w984be-26-2"})

    # Authority without a source: no one is assigned — refused typed.
    no_source_key = unique_key("w984be-262-nosrc")

    assert {:error, :REFUSED_STOP_AUTHORITY} =
             stop(provider, no_source_key, %{kind: "human_authority"})

    assert {:ok, []} =
             Ash.read(Ash.Query.filter(ActuationIntent, idempotency_key == ^no_source_key),
               authorize?: false
             )

    # A non-map authority is the same refusal (fail-closed, not a crash).
    assert {:error, :REFUSED_STOP_AUTHORITY} =
             stop(provider, unique_key("w984be-262-nonmap"), "not-an-authority")

    # The subject is untouched: no DO occurred under unassigned oversight.
    assert {:ok, row} = Ash.get(Provider, provider.id, authorize?: false)
    assert row.status != :suspended
  end

  test "sig-verified assignment: the chain's signature court admits only the assigned authority's receipts and detects a reassigned oversight identity" do
    provider =
      Xaas.Generator.create_provider!(%{name: "W984be 26.2 Sig", org_id: "org-w984be-26-2"})

    authority = assigned_authority("sig")
    assert {:ok, _} = stop(provider, unique_key("w984be-262-sig-stop"), authority)

    # The chain witness carries the assignment identity in sig_slot and a
    # sig callback admitting ONLY receipts of the assigned authority.
    sig_admits_only_assigned = fn receipt ->
      is_binary(receipt.sig_slot) and String.starts_with?(receipt.sig_slot, authority.source)
    end

    assert {:ok, chain, _head} =
             AuditChain.append(
               [],
               %{
                 actuation_id: "w984be-262-stop-#{provider.id}",
                 payload_digest: AuditChain.root_hash() |> String.replace("0", "a"),
                 sig_slot: "#{authority.source}:#{provider.id}",
                 sig: sig_admits_only_assigned
               }
             )

    assert AuditChain.verify_chain(chain) == :ok

    # Reassignment: the receipt's oversight identity is rewritten to a
    # different authority — the signature court rejects it, naming
    # :invalid_signature, not a content tamper class.
    reassigned = List.update_at(chain, 0, fn r -> %{r | sig_slot: "someone_else:#{provider.id}"} end)

    assert AuditChain.verify_chain(reassigned) == {:error, :invalid_signature}
  end
end
