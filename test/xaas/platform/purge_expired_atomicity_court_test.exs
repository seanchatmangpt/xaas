defmodule Xaas.Platform.PurgeExpiredAtomicityCourtTest do
  @moduledoc """
  W981d court for the W946e strict-sweep Exclusion 2 removal:
  `Xaas.Platform.RouteProjectsBackups.purge_expired` must run as a single
  set-based, atomic-capable bulk operation with no per-row operator read.

  Chicago-style: real Ash actions against real sandboxed Postgres, real
  policy evaluation with `authorize?: true`, assertions on resulting row
  state (never call counts).
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Platform.RouteProjectsBackups

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org_actor(slug), do: %{org_id: slug}

  defp uniq(suffix), do: "w981d-#{suffix}-#{System.unique_integer([:positive])}"

  defp create_backup!(org, suffix, retain_until) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    RouteProjectsBackups
    |> Ash.Changeset.for_create(:create, %{
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
    authorize?: true)
    |> Ash.create!()
  end

  defp live_ids(org) do
    RouteProjectsBackups
    |> Ash.Query.filter(org_id == ^org)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
    |> MapSet.new()
  end

  test "(1) set-based bulk purge: expired rows purged, non-expired and cross-org rows survive, in one atomic bulk operation" do
    org = uniq("org")
    other = uniq("other")

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    past = DateTime.add(now, -3_600, :second)
    future = DateTime.add(now, 7 * 24 * 3_600, :second)

    expired_a = create_backup!(org, "expired-a", past)
    expired_b = create_backup!(org, "expired-b", now)
    kept = create_backup!(org, "kept", future)
    foreign = create_backup!(other, "foreign", past)

    # single set-based purge over a filter query -- strategy pinned to
    # :atomic so success itself proves the action is atomic-capable (no
    # per-row operator read, no streaming fallback)
    bulk =
      RouteProjectsBackups
      |> Ash.Query.filter(org_id == ^org and retain_until <= ^now)
      |> Ash.bulk_destroy!(:purge_expired, %{},
        actor: org_actor(org),
        authorize?: true,
        strategy: [:atomic]
      )

    assert bulk.status == :success
    assert bulk.error_count == 0

    # resulting state: both expired rows really gone from disk
    surviving = live_ids(org)
    refute MapSet.member?(surviving, expired_a.id)
    refute MapSet.member?(surviving, expired_b.id)
    assert MapSet.member?(surviving, kept.id)

    # non-expired row still fully intact
    assert %RouteProjectsBackups{status: :pending} =
             Ash.get!(RouteProjectsBackups, kept.id, authorize?: false)

    # cross-org row untouched
    assert MapSet.member?(live_ids(other), foreign.id)
  end

  test "(2) no-match bulk purge is a typed success with zero rows affected" do
    org = uniq("org")
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    future = DateTime.add(now, 7 * 24 * 3_600, :second)

    row = create_backup!(org, "future", future)

    bulk =
      RouteProjectsBackups
      |> Ash.Query.filter(org_id == ^org and retain_until <= ^now)
      |> Ash.bulk_destroy!(:purge_expired, %{},
        actor: org_actor(org),
        authorize?: true,
        strategy: [:atomic]
      )

    assert bulk.status == :success
    assert bulk.error_count == 0
    assert MapSet.equal?(live_ids(org), MapSet.new([row.id]))
  end

  test "(3) atomic validation still refuses a not-yet-expired row through the per-row path (fail closed, row survives)" do
    org = uniq("org")
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    future = DateTime.add(now, 3_600, :second)

    row = create_backup!(org, "future", future)

    assert_raise Ash.Error.Invalid, fn ->
      row
      |> Ash.Changeset.for_destroy(:purge_expired, %{},
        actor: org_actor(org),
        authorize?: true
      )
      |> Ash.destroy!()
    end

    assert %RouteProjectsBackups{} = Ash.get!(RouteProjectsBackups, row.id, authorize?: false)
  end

  test "(4) cross-org actor cannot purge via bulk (policy filter check refuses, rows survive)" do
    org = uniq("org")
    attacker = uniq("attacker")

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    past = DateTime.add(now, -3_600, :second)

    row = create_backup!(org, "target", past)

    # the attacker's own bulk query (their org), not the victim's rows --
    # nothing matches, so nothing is destroyed
    bulk =
      RouteProjectsBackups
      |> Ash.Query.filter(org_id == ^attacker and retain_until <= ^past)
      |> Ash.bulk_destroy!(:purge_expired, %{},
        actor: org_actor(attacker),
        authorize?: true,
        strategy: [:atomic]
      )

    assert bulk.status == :success
    assert bulk.error_count == 0
    assert MapSet.member?(live_ids(org), row.id)

    # and a direct attempt at the victim's rows is a typed refusal: the
    # bulk result is :error (Forbidden), and the victim's row survives on
    # disk
    refused =
      RouteProjectsBackups
      |> Ash.Query.filter(org_id == ^org and retain_until <= ^past)
      |> Ash.bulk_destroy(:purge_expired, %{},
        actor: org_actor(attacker),
        authorize?: true,
        strategy: [:atomic]
      )

    assert refused.status == :error
    assert [%Ash.Error.Forbidden{}] = refused.errors
    assert MapSet.member?(live_ids(org), row.id)
  end
end
