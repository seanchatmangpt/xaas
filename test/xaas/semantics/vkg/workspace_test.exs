defmodule Xaas.Semantics.VKG.WorkspaceTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.VKG
  alias Xaas.Semantics.VKG.{Replay, Workspace}

  @engine Xaas.Test.VKGObservationEngine

  test "workspace composes independent witnesses without losing receipts" do
    assert {:ok, customer} =
             VKG.observe(
               %{
                 id: "workspace-customers",
                 contract_ids: ["customer"],
                 purpose: :engineering_read
               },
               engine: @engine,
               rows_by_contract: %{
                 "customer" => [
                   %{"subject" => "urn:party:1", "name" => "Ada"}
                 ]
               }
             )

    assert {:ok, order} =
             VKG.observe(
               %{
                 id: "workspace-orders",
                 contract_ids: ["order"],
                 purpose: :process_intelligence
               },
               engine: @engine,
               rows_by_contract: %{
                 "order" => [
                   %{
                     "subject" => "urn:order:10",
                     "customer" => "urn:party:1",
                     "amount" => "42"
                   }
                 ]
               }
             )

    assert {:ok, workspace} = Workspace.build("engineering-workspace", [order, customer])
    assert :ok = Workspace.verify(workspace)
    assert Workspace.subjects(workspace) == ["urn:order:10", "urn:party:1"]
    assert workspace.authority == :NONE

    index = Workspace.witness_index(workspace)
    assert Map.keys(index) |> Enum.sort() ==
             ["workspace-customers", "workspace-orders"]

    assert {:ok, provenance} = Workspace.provenance(workspace, "urn:party:1")
    assert [%{"contract_id" => "customer"}] = provenance

    assert {:ok, replay} = Replay.workspace(workspace)
    assert replay.deterministic?
    assert replay.witness_count == 2
    assert replay.authority == :NONE
  end

  test "duplicate query identities refuse ambiguous workspace composition" do
    attrs = %{
      id: "same-query",
      contract_ids: ["customer"],
      purpose: :engineering_read
    }

    assert {:ok, first} = VKG.observe(attrs, engine: @engine)
    assert {:ok, second} = VKG.observe(attrs, engine: @engine)

    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_WORKSPACE}} =
             Workspace.build("ambiguous", [first, second])
  end

  test "missing workspace subject is a typed refusal" do
    assert {:ok, witness} =
             VKG.observe(
               %{
                 id: "one-query",
                 contract_ids: ["customer"],
                 purpose: :knowledge_lookup
               },
               engine: @engine
             )

    assert {:ok, workspace} = Workspace.build("lookup", [witness])

    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_WORKSPACE}} =
             Workspace.fetch(workspace, "urn:missing")
  end
end
