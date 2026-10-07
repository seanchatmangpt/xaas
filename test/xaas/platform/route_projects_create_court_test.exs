defmodule Xaas.Platform.RouteProjectsCreateCourtTest do
  @moduledoc """
  W969c / SPEC-21 (W770-GAP-3) regression court: RouteProjects `:create`
  half of the maker-checker pair, gated by `Xaas.Checks.SystemActor`
  (matching the flags/secrets/approve mutation gate).

  Chicago-style: real Ash actions, real sandboxed Postgres, real policy
  evaluation with `authorize?: true`, real row state asserted after every
  transition. No mocks.

  ## Mutation rationale (anti-vacuity)

  Each assertion kills a specific mutation of `lib/xaas/platform/
  route_projects.ex`:

  - deleting the `create :create` action -> test (a)/(d) raise ArgumentError;
  - removing the `bypass action(:create) SystemActor` policy -> test (b)
    raises Ash.Error.Forbidden even for @internal_api (deny floor);
  - widening `:create` to accept `:approved_by` (mutation: skipping
    maker-checker by minting pre-approved rows) -> test (e) fails because
    an accepted approved_by would persist instead of being refused.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Platform.RouteProjects

  @internal_api Xaas.SystemAuthority.new(:internal_api)
  @oban_scheduler Xaas.SystemAuthority.new(:oban_scheduler)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # (a) the create half is real: mints a pending row with approved_by nil
  test "(a) :create mints a real pending row" do
    requester = "w969c-maker-#{System.unique_integer([:positive])}"

    row =
      RouteProjects
      |> Ash.Changeset.for_create(:create, %{requested_by: requester},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.create!()

    assert %RouteProjects{requested_by: ^requester, approved_by: nil} =
             Ash.get!(RouteProjects, row.id, authorize?: false)
  end

  # (b) the SystemActor gate is real on :create: non-system actor refused
  test "(b) non-system actor is refused typed on :create" do
    assert {:error, %Ash.Error.Forbidden{}} =
             RouteProjects
             |> Ash.Changeset.for_create(:create, %{requested_by: "w969c-org-actor"},
               actor: %Xaas.Accounts.User{},
               authorize?: true
             )
             |> Ash.create()
  end

  # (c) wrong-service system authority refused (same exact-subject law as
  # the approve half)
  test "(c) wrong-service system authority refused on :create" do
    assert {:error, %Ash.Error.Forbidden{}} =
             RouteProjects
             |> Ash.Changeset.for_create(:create, %{requested_by: "w969c-oban"},
               actor: @oban_scheduler,
               authorize?: true
             )
             |> Ash.create()
  end

  # (d) end-to-end maker-checker pair through the resource: create ->
  # distinct-actor approve persists; self-approve refused
  test "(d) create then approve completes the maker-checker pair" do
    requester = "w969c-pair-maker-#{System.unique_integer([:positive])}"

    row =
      RouteProjects
      |> Ash.Changeset.for_create(:create, %{requested_by: requester},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.create!()

    assert_raise Ash.Error.Invalid, fn ->
      row
      |> Ash.Changeset.for_update(:approve, %{approved_by: requester},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.update!()
    end

    approved =
      row
      |> Ash.Changeset.for_update(:approve, %{approved_by: "w969c-checker"},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.update!()

    assert approved.approved_by == "w969c-checker"

    assert %RouteProjects{approved_by: "w969c-checker"} =
             Ash.get!(RouteProjects, row.id, authorize?: false)
  end

  # (e) mutation kill: :create must NOT accept :approved_by (a pre-approved
  # mint would bypass maker-checker entirely)
  test "(e) :create does not accept :approved_by" do
    accepted =
      RouteProjects
      |> Ash.Resource.Info.action(:create)
      |> Map.get(:accept)

    refute :approved_by in accepted,
           ":create must not accept :approved_by -- a pre-approved mint bypasses maker-checker"
  end
end
