defmodule Xaas.Deepening.Art266RetentionDurableRowTest do
  @moduledoc """
  Lane W981t — evidenced-line deepening, corpus line **26.6** (Art. 26.6,
  affected deployer — record-keeping: logs preserved).

  Prior coverage of 26.6 asserts only the *typed structure* of
  `Xaas.Semantics.OversightGovernance.retention_policy/0`
  (`test/xaas/semantics/oversight_governance_test.exs` — the map shape and
  path existence). This court deepens it by binding the policy to the REAL
  durable row: an actual `Xaas.Actuation.run/4` over a real
  `Xaas.Marketplace.Provider` in sandboxed Postgres must write a real
  `Xaas.Operations.ActuationReceipt` row carrying the tamper-evidence
  hashes, and a same-key replay must NOT add a second row (the "permanent
  by default" claim is witnessed, not promised).

  Mutation rationale: deleting `ontology_projection_hash` /
  `input_hash` / `result_hash` population from the receipt-writing path in
  `lib/xaas/actuation.ex` (or making the receipt write conditional on a
  non-hash field) makes the hash-presence assertions fail while the
  structure-only court in oversight_governance_test.exs still passes —
  exactly the drift this deepening court exists to catch.

  Chicago discipline: real Ash actions, real actuation kernel, real
  sandboxed Postgres. No mocks.
  """

  use ExUnit.Case, async: true

  # 26.6 is an evidenced corpus line (w537 flip) — belongs in the eu_ai_act census.
  @moduletag :eu_ai_act

  require Ash.Query

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}
  alias Xaas.Semantics.OversightGovernance

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_provider! do
    Xaas.Generator.create_provider!(%{
      name: "W981t Retention Provider",
      org_id: "org-w981t-266"
    })
  end

  defp authority, do: %{kind: "test_authority", source: "w981t_266_retention_test"}

  defp actuate!(provider) do
    key = "w981t-266-#{System.unique_integer([:positive])}"

    assert {:ok, envelope} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: authority()
             )

    assert envelope.status == :succeeded
    {key, envelope}
  end

  test "a real actuation writes a durable receipt row with all tamper-evidence hashes" do
    provider = create_provider!()
    {key, envelope} = actuate!(provider)

    assert {:ok, [intent]} =
             Ash.read(Ash.Query.filter(ActuationIntent, idempotency_key == ^key),
               authorize?: false
             )

    # The receipt row is durable: readable back from the real store via its intent.
    assert {:ok, receipts} =
             Ash.read(Ash.Query.filter(ActuationReceipt, intent_id == ^intent.id),
               authorize?: false
             )

    assert [row] = receipts
    assert row.id == envelope.receipt.id
    assert row.status == :succeeded
    assert row.ontology_projection_hash == Provider.ontology_projection_hash()
    assert is_binary(row.input_hash) and row.input_hash != ""
    assert is_binary(row.result_hash) and row.result_hash != ""
    assert %DateTime{} = row.completed_at

    # The subject transition really happened under the same seal.
    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) ==
             :active
  end

  test "the intent + receipt pair survives as the retention substrate the policy names" do
    provider = create_provider!()
    {key, _envelope} = actuate!(provider)

    assert {:ok, [%ActuationIntent{}] = intents} =
             Ash.read(Ash.Query.filter(ActuationIntent, idempotency_key == ^key),
               authorize?: false
             )

    intent = hd(intents)

    assert {:ok, [receipt]} =
             Ash.read(Ash.Query.filter(ActuationReceipt, intent_id == ^intent.id),
               authorize?: false
             )

    assert is_struct(receipt, ActuationReceipt)
    assert receipt.intent_id == intent.id

    # retention_policy/0 names the actuation surface as the permanent substrate;
    # the court proves that substrate is a real row pair, not a prose promise.
    assert {:ok, policy} = OversightGovernance.retention_policy()
    assert policy.actuation_receipts == :permanent_durable_rows
    assert "lib/xaas/actuation.ex" in policy.source
    assert "lib/xaas/witness/audit_chain.ex" in policy.source
  end

  test "same-key replay adds no second row (permanence is not duplication)" do
    provider = create_provider!()
    {key, _envelope} = actuate!(provider)

    assert {:ok, [intent]} =
             Ash.read(Ash.Query.filter(ActuationIntent, idempotency_key == ^key),
               authorize?: false
             )

    assert {:ok, before} =
             Ash.read(Ash.Query.filter(ActuationReceipt, intent_id == ^intent.id),
               authorize?: false
             )

    assert {:ok, replay} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: authority()
             )

    assert replay.status == :replayed
    assert replay.replay?
    assert replay.receipt.id == hd(before).id

    assert {:ok, after_rows} =
             Ash.read(Ash.Query.filter(ActuationReceipt, intent_id == ^intent.id),
               authorize?: false
             )

    assert length(after_rows) == length(before)
  end
end
