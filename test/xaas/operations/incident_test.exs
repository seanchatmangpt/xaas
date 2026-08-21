defmodule Xaas.Operations.IncidentTest do
  @moduledoc """
  Real Chicago-style tests: real Ash actions against the real sandboxed
  Postgres (Xaas.Repo), authorize?: false (system-internal path -- this
  resource's json_api routes block exists but is not actually wired into
  KanbanWeb.InternalApiRouter/ApiRouter, so there is no real controller to
  test against; see docs/claude/diataxis/reference/http-api-surface.md).

  Also proves the real query pattern
  `Xaas.Governance.Validations.ApprovalDrFailoverRequiresOpenIncident`
  depends on -- `region == ^from_region and status == "open"` -- actually
  returns only the matching-region, open incident.
  """
  use ExUnit.Case, async: true

  alias Xaas.Operations.Incident

  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org_id, do: "org-#{System.unique_integer([:positive])}"

  defp create!(attrs) do
    Incident
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  test "a real incident can be created with real fields and persisted values assert" do
    org = org_id()
    opened_at = DateTime.utc_now() |> DateTime.truncate(:second)

    incident =
      create!(%{
        org_id: org,
        title: "us-east-1 primary DB unreachable",
        region: "us-east-1",
        severity: :critical,
        opened_at: opened_at
      })

    assert incident.org_id == org
    assert incident.title == "us-east-1 primary DB unreachable"
    assert incident.region == "us-east-1"
    assert incident.severity == :critical
    assert incident.status == :open
    assert incident.opened_at == opened_at

    persisted = Incident |> Ash.get!(incident.id, authorize?: false)
    assert persisted.title == incident.title
    assert persisted.region == incident.region
  end

  test "a real incident can be updated to resolved with a real resolved_at, persisted change asserted" do
    incident =
      create!(%{
        org_id: org_id(),
        title: "eu-west-1 elevated error rate",
        region: "eu-west-1",
        severity: :major,
        opened_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    resolved_at = DateTime.utc_now() |> DateTime.truncate(:second)

    updated =
      incident
      |> Ash.Changeset.for_update(:update, %{
        status: :resolved,
        resolved_at: resolved_at,
        postmortem_root_cause: "connection pool exhaustion",
        postmortem_status: :final
      })
      |> Ash.update!(authorize?: false)

    assert updated.status == :resolved
    assert updated.resolved_at == resolved_at
    assert updated.postmortem_root_cause == "connection pool exhaustion"
    assert updated.postmortem_status == :final

    persisted = Incident |> Ash.get!(incident.id, authorize?: false)
    assert persisted.status == :resolved
    assert persisted.resolved_at == resolved_at
  end

  test "filtering on region + status == open (the real query ApprovalDrFailoverRequiresOpenIncident depends on) returns only the matching open incident" do
    region = "ap-southeast-2-#{System.unique_integer([:positive])}"
    other_region = "us-west-2-#{System.unique_integer([:positive])}"
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    open_in_region =
      create!(%{
        org_id: org_id(),
        title: "region under failover consideration",
        region: region,
        severity: :critical,
        status: :open,
        opened_at: now
      })

    _resolved_in_region =
      create!(%{
        org_id: org_id(),
        title: "already resolved incident in same region",
        region: region,
        severity: :minor,
        status: :resolved,
        opened_at: now
      })

    _open_in_other_region =
      create!(%{
        org_id: org_id(),
        title: "open incident but wrong region",
        region: other_region,
        severity: :critical,
        status: :open,
        opened_at: now
      })

    query =
      Incident
      |> Ash.Query.filter(region == ^region and status == "open")

    results = Ash.read!(query, authorize?: false)

    assert Enum.map(results, & &1.id) == [open_in_region.id]
  end
end
