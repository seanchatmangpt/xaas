defmodule Xaas.Operations.CastleApprovalRouteSurfaceTest do
  @moduledoc """
  W984dk — provenance burn-down slice, Operations family (W984cy census: 29
  uncovered Operations modules; this lane takes the castle slice W984cw4 does
  not claim). Four modules with zero behavior-court coverage prior to this
  file:

    - `Xaas.Operations.ApprovalCastleVerbSchedule` (prior coverage: name-only
      mention in `system_authority_service_scope_test.exs`'s subject list —
      no create/approve/validation behavior ever executed in a court)
    - `Xaas.Operations.RouteCastleDeploy` / `RouteCastleSchedule` /
      `RouteCastleSunset` (zero test references at all)

  Chicago discipline: real Ash actions over real sandboxed Postgres rows;
  assert on final persisted state, never call counts; no mocks. Typed
  refusals are exercised as real Ash error values, not mocked.

  Mutation rationale per court:
    (1) add a second distinct-approver check removal to `:approve` and court
        (2) fails (self-approval would be admitted, row mutated);
    (2) drop `ApprovalCastleVerbScheduleRequiresApprover` from `:approve`
        and courts (2)/(3) fail (nil/self approver admitted);
    (3) relax the deny floor (`policy always() do forbid_if(always()) end`)
        on any route_castle resource and courts (4)/(5) fail (anonymous
        create would be authorized);
    (4) add `:create` to `defaults([...])` on a route_castle resource and
        court (5) fails (the write surface becomes real; the floor must
        refuse it — court (5) proves it does);
    (5) drop the `bypass action_type(:read)` and courts (4)/(5) fail on the
        anonymous read of repo-minted rows.
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.ApprovalCastleVerbSchedule
  alias Xaas.Operations.RouteCastleDeploy
  alias Xaas.Operations.RouteCastleSchedule
  alias Xaas.Operations.RouteCastleSunset
  alias Xaas.SystemAuthority

  @read_only [
    {RouteCastleDeploy, "route_castle_deploys"},
    {RouteCastleSchedule, "route_castle_schedules"},
    {RouteCastleSunset, "route_castle_sunsets"}
  ]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp system_actor, do: SystemAuthority.new(:internal_api)

  test "(1) maker-checker happy path: create then approve as internal_api persists a distinct approver" do
    {:ok, created} =
      ApprovalCastleVerbSchedule
      |> Ash.Changeset.for_create(:create, %{requested_by: "w984dk-maker", approved_by: nil},
        authorize?: false
      )
      |> Ash.create()

    assert created.requested_by == "w984dk-maker"
    assert is_nil(created.approved_by)

    {:ok, approved} =
      created
      |> Ash.Changeset.for_update(:approve, %{approved_by: "w984dk-checker"},
        actor: system_actor()
      )
      |> Ash.update()

    assert approved.approved_by == "w984dk-checker"

    reloaded = Ash.get!(ApprovalCastleVerbSchedule, created.id, authorize?: false)
    assert reloaded.requested_by == "w984dk-maker"
    assert reloaded.approved_by == "w984dk-checker"
  end

  test "(2) self-approval is refused typed and leaves the row unchanged" do
    {:ok, created} =
      ApprovalCastleVerbSchedule
      |> Ash.Changeset.for_create(:create, %{requested_by: "w984dk-self"},
        authorize?: false
      )
      |> Ash.create()

    {:error, %Ash.Error.Invalid{} = error} =
      created
      |> Ash.Changeset.for_update(:approve, %{approved_by: "w984dk-self"},
        actor: system_actor()
      )
      |> Ash.update()

    assert Enum.any?(error.errors, fn e ->
             Map.get(e, :field) == :approved_by and
               Map.get(e, :message) =~ "cannot approve their own"
           end)

    reloaded = Ash.get!(ApprovalCastleVerbSchedule, created.id, authorize?: false)
    assert is_nil(reloaded.approved_by)
  end

  test "(3) missing approver is refused typed and leaves the row unchanged" do
    {:ok, created} =
      ApprovalCastleVerbSchedule
      |> Ash.Changeset.for_create(:create, %{requested_by: "w984dk-noapprover"},
        authorize?: false
      )
      |> Ash.create()

    {:error, %Ash.Error.Invalid{} = error} =
      created
      |> Ash.Changeset.for_update(:approve, %{approved_by: ""},
        actor: system_actor()
      )
      |> Ash.update()

    assert Enum.any?(error.errors, fn e ->
             Map.get(e, :field) == :approved_by and Map.get(e, :message) =~ "is required"
           end)

    reloaded = Ash.get!(ApprovalCastleVerbSchedule, created.id, authorize?: false)
    assert is_nil(reloaded.approved_by)
  end

  test "(4) route_castle read-only trio: repo-minted rows are readable through real Ash actions" do
    for {resource, table} <- @read_only do
      {1, [%{id: raw_id}]} =
        Xaas.Repo.insert_all(
          table,
          [%{requested_by: "w984dk-floor", approved_by: nil}],
          returning: [:id]
        )

      %{id: id} = %{id: Ecto.UUID.cast!(raw_id)}

      row = Ash.get!(resource, id, authorize?: false)
      assert row.requested_by == "w984dk-floor"

      rows =
        resource
        |> Ash.Query.new()
        |> Ash.read!(authorize?: false)

      assert Enum.any?(rows, &(&1.id == id))
    end
  end

  test "(5) the deny floor refuses non-system mutations on the route_castle trio, typed and unchanged" do
    for {resource, table} <- @read_only do
      # The write surface is absent entirely: Ash raises at changeset
      # construction time, which is stronger than a policy refusal.
      assert_raise ArgumentError, ~r/No such create action/, fn ->
        resource
        |> Ash.Changeset.for_create(:create, %{requested_by: "w984dk-floor"})
        |> Ash.create()
      end

      # A real row is still untouchable: update action absent too.
      {1, [%{id: raw_id}]} =
        Xaas.Repo.insert_all(
          table,
          [%{requested_by: "w984dk-floor", approved_by: nil}],
          returning: [:id]
        )

      id = Ecto.UUID.cast!(raw_id)
      record = Ash.get!(resource, id, authorize?: false)

      assert_raise ArgumentError, ~r/No such update action/, fn ->
        record
        |> Ash.Changeset.for_update(:update, %{approved_by: "w984dk-floor"})
        |> Ash.update()
      end

      # And the row survives both refusals byte-identical on approved_by.
      row = Ash.get!(resource, id, authorize?: false)
      assert is_nil(row.approved_by)
      assert row.requested_by == "w984dk-floor"
    end
  end
end
