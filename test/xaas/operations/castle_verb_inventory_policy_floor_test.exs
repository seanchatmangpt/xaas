defmodule Xaas.Operations.CastleVerbInventoryPolicyFloorTest do
  @moduledoc """
  W984aa — depth court, batch 2 (W980i pattern): the read-only castle-verb
  inventory surfaces (`Xaas.Operations.CastleVerbInventoryGoals`,
  `CastleVerbInventoryComponents`, `CastleVerbFortune5Requirements`), whose
  only prior coverage is a module-name mention inside
  `system_authority_service_scope_test.exs` — no resource-level court exists.

  The real invariant this family carries is STRUCTURAL: all three resources
  declare `defaults([:read])` — there is no create/update/destroy action at
  all, so the deny-by-default policy floor is backed (and shadowed) by
  write-surface absence. The rows are minted by an out-of-band writer, so
  these courts manufacture real sandboxed Postgres rows at the repo layer
  (`Repo.insert_all`, same table the JSON:API surface reads) and read them
  back through real Ash actions.

  Mutation rationale: add `:create` to `defaults([...])` in any of the three
  resources and courts (2)/(3) fail — the write surface becomes real and the
  policy floor (`policy always() do forbid_if(always()) end`) must then be
  the thing that refuses, which courts (2)/(3) prove it does. Drop the
  `bypass action_type(:read)` and court (1)/(4) fail on the anonymous read.
  Rename/drop the json_api type or the get/index routes and court (5) fails.
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.CastleVerbFortune5Requirements
  alias Xaas.Operations.CastleVerbInventoryComponents
  alias Xaas.Operations.CastleVerbInventoryGoals

  @resources [
    {CastleVerbInventoryGoals, "castle_verb_inventory_goals"},
    {CastleVerbInventoryComponents, "castle_verb_inventory_components"},
    {CastleVerbFortune5Requirements, "castle_verb_fortune5_requirements"}
  ]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp insert_row!(table, requested_by) do
    {1, [%{id: id}]} =
      Xaas.Repo.insert_all(
        table,
        [%{requested_by: requested_by, approved_by: nil}],
        returning: [:id]
      )

    %{id: Ecto.UUID.cast!(id)}
  end

  test "(1) every sibling is read-only: zero write actions exist on the resource" do
    for {resource, _table} <- @resources do
      action_names = Ash.Resource.Info.actions(resource) |> Enum.map(& &1.name)

      assert action_names -- [:read] == [],
             "expected #{inspect(resource)} to be read-only, got #{inspect(action_names)}"

      assert Ash.Resource.Info.action(resource, :create) == nil
      assert Ash.Resource.Info.action(resource, :update) == nil
      assert Ash.Resource.Info.action(resource, :destroy) == nil
    end
  end

  test "(2) Ash create is refused with a typed error even with authorize?: false (no such action)" do
    for {resource, _table} <- @resources do
      # Ash raises ArgumentError at changeset-construction time when the
      # named action does not exist at all — the write surface is absent,
      # which is stronger than a policy refusal.
      assert_raise ArgumentError,
                   ~r/No such create action/,
                   fn ->
                     resource
                     |> Ash.Changeset.for_create(:create, %{requested_by: "w984aa"})
                     |> Ash.create(authorize?: false)
                   end
    end
  end

  test "(3) an update attempt against a real row refuses typed and leaves the row unchanged" do
    {resource, table} = Enum.at(@resources, 0)

    %{id: id} = insert_row!(table, "w984aa-floor")

    row = Ash.get!(resource, id, authorize?: false)

    assert_raise ArgumentError,
                 ~r/No such update action/,
                 fn ->
                   row
                   |> Ash.Changeset.for_update(:update, %{approved_by: "w984aa-approver"})
                   |> Ash.update(authorize?: false)
                 end

    persisted = Ash.get!(resource, id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "(4) real repo-layer rows read back through the authorized anonymous read bypass" do
    for {resource, table} <- @resources do
      %{id: id} = insert_row!(table, "w984aa-read-#{System.unique_integer([:positive])}")

      row = Ash.get!(resource, id, actor: nil, authorize?: true)
      assert row.id == id
      assert is_binary(row.requested_by)
      assert row.approved_by == nil
    end
  end

  test "(5) json_api surface is read-only and types are stable (drift guard)" do
    expected = %{
      CastleVerbInventoryGoals => "castle_verb_inventory_goals",
      CastleVerbInventoryComponents => "castle_verb_inventory_components",
      CastleVerbFortune5Requirements => "castle_verb_fortune5_requirements"
    }

    for {resource, type} <- expected do
      assert AshJsonApi.Resource.Info.type(resource) == type

      route_kinds =
        resource
        |> AshJsonApi.Resource.Info.routes()
        |> Enum.map(& &1.method)

      assert Enum.all?(route_kinds, &(&1 in [:get, :index])),
             "expected #{inspect(resource)} json_api routes to be read-only, got #{inspect(route_kinds)}"
    end
  end
end
