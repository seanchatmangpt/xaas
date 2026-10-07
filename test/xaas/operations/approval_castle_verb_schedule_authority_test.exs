defmodule Xaas.Operations.ApprovalCastleVerbScheduleAuthorityTest do
  @moduledoc """
  W984dp2 — Operations residue slice, complementary to W984dk's landed
  `castle_approval_route_surface_test.exs` (which courts the maker-checker
  happy path, the two `RequiresApprover` typed refusals, the read-only
  route_castle trio reads, and the missing write actions). Zero overlap with
  that file: this court exercises the *authorization* surface of
  `Xaas.Operations.ApprovalCastlePolicyVerbSchedule`'s family member
  `Xaas.Operations.ApprovalCastleVerbSchedule` that W984dk never ran:

    - non-system actors on `:create`/`:approve` (the `{Xaas.Checks.SystemActor,
      system_actor: :internal_api}` bypasses are the only mutation authority;
      the deny floor `policy always() do forbid_if(always()) end` must refuse
      everything else, typed `Ash.Error.Forbidden`)
    - the read bypass admitting anonymous reads (authorize?: true) of real
      persisted rows — the deny floor does NOT cover reads
    - the `:create` accept list (approved_by accepted at create time)

  Chicago discipline: real Ash actions over real sandboxed Postgres rows;
  assert on final persisted state; no mocks; typed refusals as real Ash
  error values.

  Mutation rationale per court:
    (1) remove the `bypass action(:create)` and court (1) fails (system
        actor denied — no mutation authority survives);
    (2) replace either `Xaas.Checks.SystemActor` bypass with
        `authorize_if(always())` and courts (1)/(2) fail (anonymous
        mutation admitted — the exact regression XAAS-2602 closed);
    (3) drop the `bypass action_type(:read)` and court (3) fails
        (anonymous read of a real row refused);
    (4) remove `:approved_by` from the `:create` accept list and court (4)
        fails (pre-approval at creation silently dropped);
    (5) drop the deny floor and courts (1)/(2) fail (a non-mapped action
        would fall open).
  """

  use ExUnit.Case, async: false

  import Ecto.Query
  require Ash.Query

  alias Xaas.Operations.ApprovalCastleVerbSchedule
  alias Xaas.SystemAuthority

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp system_actor, do: SystemAuthority.new(:internal_api)

  test "(1) anonymous :create is refused typed and persists nothing" do
    {:error, %Ash.Error.Forbidden{}} =
      ApprovalCastleVerbSchedule
      |> Ash.Changeset.for_create(:create, %{requested_by: "w984dp2-anon"},
        actor: nil,
        authorize?: true
      )
      |> Ash.create()

    refute Xaas.Repo.exists?(
             from(c in "approval_castle_verb_schedules",
               where: c.requested_by == ^"w984dp2-anon"
             )
           )
  end

  test "(2) anonymous :approve is refused typed and leaves the row unchanged" do
    {:ok, created} =
      ApprovalCastleVerbSchedule
      |> Ash.Changeset.for_create(:create, %{requested_by: "w984dp2-noauth"},
        authorize?: false
      )
      |> Ash.create()

    {:error, %Ash.Error.Forbidden{}} =
      created
      |> Ash.Changeset.for_update(:approve, %{approved_by: "w984dp2-anyone"},
        actor: nil,
        authorize?: true
      )
      |> Ash.update()

    reloaded = Ash.get!(ApprovalCastleVerbSchedule, created.id, authorize?: false)
    assert is_nil(reloaded.approved_by)
    assert reloaded.requested_by == "w984dp2-noauth"
  end

  test "(3) anonymous read of a persisted row is admitted via the read bypass" do
    {:ok, created} =
      ApprovalCastleVerbSchedule
      |> Ash.Changeset.for_create(:create, %{requested_by: "w984dp2-read"},
        authorize?: false
      )
      |> Ash.create()

    rows =
      ApprovalCastleVerbSchedule
      |> Ash.Query.filter(id == ^created.id)
      |> Ash.read!(actor: nil, authorize?: true)

    assert [%{requested_by: "w984dp2-read"}] = rows
    assert [%{id: id}] = rows
    assert id == created.id
  end

  test "(4) approved_by is accepted at :create (pre-approval surface) and flows through :approve" do
    {:ok, preapproved} =
      ApprovalCastleVerbSchedule
      |> Ash.Changeset.for_create(:create, %{
        requested_by: "w984dp2-pre",
        approved_by: "w984dp2-checker"
      }, authorize?: false)
      |> Ash.create()

    assert preapproved.approved_by == "w984dp2-checker"

    {:ok, _approved} =
      preapproved
      |> Ash.Changeset.for_update(:approve, %{approved_by: "w984dp2-checker2"},
        actor: system_actor()
      )
      |> Ash.update()

    reloaded = Ash.get!(ApprovalCastleVerbSchedule, preapproved.id, authorize?: false)
    assert reloaded.approved_by == "w984dp2-checker2"
  end

  test "(5) a non-system actor value is refused on :approve, row unchanged" do
    {:ok, created} =
      ApprovalCastleVerbSchedule
      |> Ash.Changeset.for_create(:create, %{requested_by: "w984dp2-odd"},
        authorize?: false
      )
      |> Ash.create()

    {:error, %Ash.Error.Forbidden{}} =
      created
      |> Ash.Changeset.for_update(:approve, %{approved_by: "w984dp2-x"},
        actor: "w984dp2-plain-string-actor",
        authorize?: true
      )
      |> Ash.update()

    reloaded = Ash.get!(ApprovalCastleVerbSchedule, created.id, authorize?: false)
    assert is_nil(reloaded.approved_by)
  end
end
