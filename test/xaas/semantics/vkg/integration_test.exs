defmodule Xaas.Semantics.VKG.IntegrationTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.VKG
  alias Xaas.Semantics.VKG.{Query, Witness}

  @engine Xaas.Test.VKGObservationEngine

  test "canonical catalog is consumed rather than reconstructed in XaaS" do
    assert {:ok, catalog} = VKG.catalog()
    ids = AshR2RML.VKG.Catalog.ids(catalog)

    assert "customer" in ids
    assert "order" in ids
    assert "product" in ids
    assert length(ids) == 10

    assert {:ok, snapshot} = VKG.catalog_snapshot()
    assert snapshot.catalog_sha256 == catalog.sha256
    assert snapshot.contract_count == 10
  end

  test "query closes admission to observation to witness to engineering consumer" do
    assert {:ok, query} =
             Query.new(%{
               id: "customer-observation",
               contract_ids: ["customer"],
               purpose: :engineering_read,
               max_rows: 100
             })

    rows = %{
      "customer" => [
        %{"subject" => "urn:customer:1", "name" => "Ada"},
        %{"subject" => "urn:customer:2", "name" => "Grace"}
      ]
    }

    assert {:ok, %Witness{} = witness} =
             VKG.observe(query, engine: @engine, rows_by_contract: rows)

    assert witness.query_id == query.id
    assert witness.contract_ids == ["customer"]
    assert witness.row_count == 2
    assert witness.authority == :NONE
    assert :ok = VKG.verify(witness)

    snapshot = VKG.engineering(witness)
    assert snapshot["row_count"] == 2
    assert snapshot["entity_count"] == 2
    assert snapshot["receipt_id"] == witness.receipt_id
    assert snapshot["authority"] == "NONE"
  end

  test "GraphQL projection preserves provenance and remains read-only" do
    assert {:ok, witness} =
             VKG.observe(
               %{
                 id: "orders-graphql",
                 contract_ids: ["order"],
                 purpose: :knowledge_lookup
               },
               engine: @engine,
               rows_by_contract: %{
                 "order" => [
                   %{"subject" => "urn:order:10", "amount" => "42"},
                   %{"subject" => "urn:order:11", "amount" => "7"}
                 ]
               }
             )

    connection = VKG.graphql(witness, first: 1)

    assert connection["authority"] == "NONE"
    assert connection["receiptId"] == witness.receipt_id
    assert [%{"node" => node, "provenance" => provenance, "cursor" => cursor}] =
             connection["edges"]

    assert node["subject"] in ["urn:order:10", "urn:order:11"]
    assert provenance["contract_id"] == "order"
    assert byte_size(provenance["source_sha256"]) == 64
    assert is_binary(cursor)
  end

  test "unknown source is refused before an observation witness exists" do
    assert {:error, %AshR2RML.Refusal{}} =
             VKG.observe(
               %{
                 id: "unknown",
                 contract_ids: ["not-admitted"],
                 purpose: :engineering_read
               },
               engine: @engine
             )
  end
end
