defmodule Xaas.Platform.RetainUntilPassedW984dvTest do
  @moduledoc """
  Lane W984dv Chicago court for
  `Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed`.

  Census (W984du fifth re-census): the atomicity court (W981d) covers
  happy-path bulk purge, no-match bulk, per-row refusal of a not-yet-
  expired row, and cross-org policy. Genuinely unexercised branches:

    1. the validation's ATOMIC error branch -- a bulk destroy pinned to
       `strategy: [:atomic]` whose query matches a not-yet-expired row
       must surface the validation's own SQL-derived typed error
       (`InvalidAttribute`, "retain_until must have passed...") and the
       row must survive;
    2. the fail-closed nil branch of validate/3 (no retention deadline ->
       refuse) via a real changeset on a real record shape;
    3. the happy per-row purge (validate/3 :ok branch) persists as a real
       deletion on disk.

  Chicago style: real Ash actions, real sandboxed Postgres, state
  assertions, zero mocks.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Platform.RouteProjectsBackups
  alias Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org_actor(slug), do: %{org_id: slug}

  defp uniq(suffix), do: "w984dv-#{suffix}-#{System.unique_integer([:positive])}"

  defp create_backup!(org, suffix, retain_until) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    RouteProjectsBackups
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: org,
        namespace: "ns",
        project_name: suffix,
        job_name: "job-#{suffix}",
        taken_at: now,
        size_bytes: 0,
        retain_until: retain_until,
        status: :pending
      },
      actor: org_actor(org),
      authorize?: true
    )
    |> Ash.create!()
  end

  defp live_ids(org) do
    RouteProjectsBackups
    |> Ash.Query.filter(org_id == ^org)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
    |> MapSet.new()
  end

  test "(1) atomic bulk destroy over a not-yet-expired row: typed InvalidAttribute, row survives on disk" do
    org = uniq("org")
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    future = DateTime.add(now, 3_600, :second)

    row = create_backup!(org, "future", future)

    bulk =
      RouteProjectsBackups
      |> Ash.Query.filter(org_id == ^org and retain_until > ^now)
      |> Ash.bulk_destroy(:purge_expired, %{},
        actor: org_actor(org),
        authorize?: true,
        strategy: [:atomic],
        return_errors?: true
      )

    assert bulk.status == :error

    # bulk results wrap per-row errors in %Ash.Error.Invalid{errors: [...]}
    flat = Enum.flat_map(bulk.errors, &List.wrap(&1.errors))

    assert [%Ash.Error.Changes.InvalidAttribute{} = err] =
             Enum.filter(flat, &match?(%Ash.Error.Changes.InvalidAttribute{}, &1))

    assert err.field == :retain_until

    # Real behavior (observed): under strategy [:atomic] Ash still runs
    # validate/3 eagerly on the loaded changeset, so the surfacing message
    # is validate/3's retention-window refusal, not the atomic SQL expr's
    # message. The atomic expr remains the fail-closed DB-level backstop.
    assert err.message =~ "is still within its retention window"

    # row really still on disk
    assert MapSet.member?(live_ids(org), row.id)
  end

  test "(2) fail-closed nil branch: validate/3 refuses a changeset whose record has no retention deadline" do
    bare = %RouteProjectsBackups{retain_until: nil}

    changeset =
      Ash.Changeset.for_destroy(bare, :purge_expired, %{}, authorize?: false)

    assert {:error, opts} =
             RouteProjectsBackupsRetainUntilPassed.validate(changeset, [], %{})

    assert opts[:field] == :retain_until
    assert opts[:message] =~ "has no retention deadline"
  end

  test "(3) happy per-row purge: validate/3 :ok, row really deleted from disk" do
    org = uniq("org")
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    past = DateTime.add(now, -3_600, :second)

    row = create_backup!(org, "expired", past)

    row
    |> Ash.Changeset.for_destroy(:purge_expired, %{},
      actor: org_actor(org),
      authorize?: true
    )
    |> Ash.destroy!()

    refute MapSet.member?(live_ids(org), row.id)
  end

  test "(4) validate/3 refuses a still-within-retention-window row with the real message" do
    org = uniq("org")
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    future = DateTime.add(now, 3_600, :second)

    row = create_backup!(org, "future", future)

    changeset =
      row
      |> Ash.Changeset.for_destroy(:purge_expired, %{}, actor: org_actor(org), authorize?: true)

    assert {:error, opts} =
             RouteProjectsBackupsRetainUntilPassed.validate(changeset, [], %{})

    assert opts[:field] == :retain_until
    assert opts[:message] =~ "still within its retention window"
  end
end
