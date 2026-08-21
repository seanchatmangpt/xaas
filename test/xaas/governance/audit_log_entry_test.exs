defmodule Xaas.Governance.AuditLogEntryTest do
  @moduledoc """
  Real Chicago-style tests: real Ash `:approve` actions against real
  Postgres-persisted `Approval*` records (via the real sandboxed
  `Xaas.Repo`), asserting a real `Xaas.Operations.AuditLogEntry` row is
  created with the real correct `action`/`resource_type`/`resource_id`/
  `actor_id`. No mocking -- `Xaas.Governance.Changes.WriteAuditLogEntry`
  runs for real via `Ash.Changeset.after_transaction/2`, exactly as it
  would in production.
  """
  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalBackupRetentionChange
  alias Xaas.Governance.ApprovalDrFailover
  alias Xaas.Governance.ApprovalLegalHoldRelease
  alias Xaas.Operations.AuditLogEntry
  alias Xaas.Operations.Incident

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp real_org_slug! do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "Test Org",
      slug: "org-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
    |> Map.fetch!(:slug)
  end

  defp audit_entries_for(resource_id) do
    AuditLogEntry
    |> Ash.Query.filter(resource_id == ^to_string(resource_id))
    |> Ash.Query.for_read(:read, %{}, authorize?: false)
    |> Ash.read!()
  end

  test "approving a real DR failover writes a real AuditLogEntry row" do
    org_id = real_org_slug!()

    Incident
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      title: "test incident",
      region: "us-east-1",
      opened_at: DateTime.utc_now()
    })
    |> Ash.create!(authorize?: false)

    record =
      ApprovalDrFailover
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org_id,
          requested_by: "requester-1",
          from_region: "us-east-1",
          to_region: "us-west-2",
          reason: "region degradation"
        },
        tenant: org_id
      )
      |> Ash.create!(authorize?: false)

    approved =
      record
      |> Ash.Changeset.for_update(:approve, %{approved_by: "owner-2"}, tenant: org_id)
      |> Ash.update!(authorize?: false)

    entries = audit_entries_for(approved.id)
    assert length(entries) == 1
    [entry] = entries

    assert entry.action == "governance.approval_dr_failover.approve"
    assert entry.resource_type == "approval_dr_failover"
    assert entry.resource_id == approved.id
    assert entry.actor_id == "owner-2"
    assert entry.org_id == org_id
  end

  test "approving a real legal hold release writes a real AuditLogEntry row" do
    org_id = real_org_slug!()

    record =
      ApprovalLegalHoldRelease
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org_id,
          requested_by: "requester-1",
          hold_id: "hold-123",
          release_reason: "hold no longer needed"
        },
        tenant: org_id
      )
      |> Ash.create!(authorize?: false)

    approved =
      record
      |> Ash.Changeset.for_update(:approve, %{approved_by: "owner-2"}, tenant: org_id)
      |> Ash.update!(authorize?: false)

    entries = audit_entries_for(approved.id)
    assert length(entries) == 1
    [entry] = entries

    assert entry.action == "governance.approval_legal_hold_release.approve"
    assert entry.resource_type == "approval_legal_hold_release"
    assert entry.resource_id == approved.id
    assert entry.actor_id == "owner-2"
    assert entry.org_id == org_id
  end

  test "approving a real backup retention change writes a real AuditLogEntry row" do
    org_id = real_org_slug!()

    record =
      ApprovalBackupRetentionChange
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org_id,
          requested_by: "requester-1",
          requested_retention_days: 5,
          tier: :starter
        },
        tenant: org_id
      )
      |> Ash.create!(authorize?: false)

    approved =
      record
      |> Ash.Changeset.for_update(:approve, %{approved_by: "owner-2"}, tenant: org_id)
      |> Ash.update!(authorize?: false)

    entries = audit_entries_for(approved.id)
    assert length(entries) == 1
    [entry] = entries

    assert entry.action == "governance.approval_backup_retention_change.approve"
    assert entry.resource_type == "approval_backup_retention_change"
    assert entry.resource_id == approved.id
    assert entry.actor_id == "owner-2"
    assert entry.org_id == org_id
  end
end
