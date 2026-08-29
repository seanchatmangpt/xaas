defmodule Xaas.ActuationTest do
  @moduledoc """
  Chicago-style qualification for the ontology-first Ash.Reactor actuation kernel.

  These tests use the real Ash resources, real Reactor, and the real sandboxed
  Postgres data layer. They prove semantic admission, bypass refusal, durable
  receipt binding, consequential mutation, and deterministic idempotent replay.
  """

  use ExUnit.Case, async: true

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.ActuationReceipt
  alias Xaas.Semantics.Registry

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_provider! do
    Provider
    |> Ash.Changeset.for_create(:create, %{
      name: "Reactor Provider",
      slug: "reactor-provider-#{System.unique_integer([:positive])}",
      org_id: "org-reactor"
    })
    |> Ash.create!(authorize?: false)
  end

  test "every provider semantic IRI is admitted from public ontologies" do
    projection = Provider.ontology_projection!()

    assert "https://schema.org/Organization" in projection.classes
    assert "http://www.w3.org/ns/prov#Agent" in projection.classes

    iris =
      projection.classes ++
        Enum.map(projection.attributes, & &1.predicate) ++
        Enum.map(projection.relationships, & &1.predicate)

    assert Enum.all?(iris, &Registry.public_iri?/1)
    assert Provider.ontology_projection_hash() == Registry.hash(projection)
    assert Provider.ontology_projection_hash() == Provider.ontology_projection_hash()
  end

  test "Reactor is the admitted DO path and replay does not repeat the mutation" do
    provider = create_provider!()
    key = "test-provider-actuation-#{System.unique_integer([:positive])}"

    assert {:error, %Ash.Error.Invalid{}} =
             provider
             |> Ash.Changeset.for_update(:activate, %{})
             |> Ash.update(authorize?: false)

    assert {:ok, first} =
             Xaas.Actuation.run(
               Provider,
               :activate,
               %{},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "actuation_test"}
             )

    assert first.status == :succeeded
    refute first.replay?
    assert first.receipt.status == :succeeded
    assert first.receipt.ontology_projection_hash == Provider.ontology_projection_hash()
    assert first.receipt.input_hash
    assert first.receipt.result_hash
    assert first.receipt.completed_at

    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :active

    receipts_before = Ash.read!(ActuationReceipt, authorize?: false)

    assert {:ok, replay} =
             Xaas.Actuation.run(
               Provider,
               :activate,
               %{},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "actuation_test"}
             )

    assert replay.status == :replayed
    assert replay.replay?
    assert replay.receipt.id == first.receipt.id
    assert length(Ash.read!(ActuationReceipt, authorize?: false)) == length(receipts_before)
  end

  test "idempotency key reuse with a different consequence is refused" do
    provider = create_provider!()
    key = "test-provider-conflict-#{System.unique_integer([:positive])}"

    assert {:ok, %{status: :succeeded}} =
             Xaas.Actuation.run(
               Provider,
               :activate,
               %{},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority"}
             )

    assert {:error, {:idempotency_conflict, ^key}} =
             Xaas.Actuation.run(
               Provider,
               :suspend,
               %{},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority"}
             )
  end
end
