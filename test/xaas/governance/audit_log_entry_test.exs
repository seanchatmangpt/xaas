defmodule Xaas.Governance.AuditLogEntryTest do
  @moduledoc """
  Real Chicago-style tests: real Ash `:approve` actions against real
  Postgres-persisted `Approval*` records (via the real sandboxed
  `Xaas.Repo`), asserting a real `Xaas.Operations.AuditLogEntry` row is
  created with the real correct `action`/`resource_type`/`resource_id`/
  `actor_id`. No mocking -- `Xaas.Governance.Changes.WriteAuditLogEntry`
  runs for real via `Ash.Changeset.after_action/2`, exactly as it would
  in production.
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

  # Real Chicago-style coverage for the atomic-write fix
  # (Xaas.Governance.Changes.WriteAuditLogEntry now uses
  # `Ash.Changeset.after_action/2`, not `after_transaction/2`): a real
  # AuditLogEntry write failure must roll back the parent `:approve`
  # action's own committed state too -- never leave a record
  # "approved but silently un-audited forever."
  #
  # This forces a REAL write failure, not a mock and not a timing-
  # dependent race. `Xaas.Operations.AuditLogEntry` has no real,
  # legitimately-triggerable unique/check constraint today: `action`/
  # `resource_type` are static strings owned by the calling resource's
  # own action definition, `resource_id` is always `to_string(record.id)`,
  # and every other column real `Approval*` data can reach is nullable --
  # so unlike round 7's `AshDoubleEntry.Transfer.Changes.VerifyTransfer`
  # trick, there is no pre-existing real validation to lean on here.
  # Disclosed here rather than silently reaching for a mock: instead, add
  # a real Postgres CHECK constraint via raw SQL, scoped to *this test's
  # own* sandboxed transaction only. Postgres DDL (including ADD
  # CONSTRAINT) is fully transactional, and `Ecto.Adapters.SQL.Sandbox`
  # wraps this whole test in one transaction that is rolled back at
  # checkin -- so the constraint never touches the real schema, is
  # invisible to every other (possibly concurrent, `async: true`) test's
  # own connection, and disappears automatically when this test ends. The
  # constraint is written to be trivially violated by the real, static
  # `action` string this change module always writes, forcing a genuine
  # constraint-violation error out of the real `Ash.create/2` call.
  test "a real forced AuditLogEntry write failure rolls back approved_by too -- never approved-but-unaudited" do
    Xaas.Repo.query!(
      "ALTER TABLE audit_log_entries ADD CONSTRAINT force_test_write_failure " <>
        "CHECK (action = 'IMPOSSIBLE_VALUE_TO_FORCE_A_REAL_CONSTRAINT_FAILURE')"
    )

    org_id = real_org_slug!()

    record =
      ApprovalLegalHoldRelease
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org_id,
          requested_by: "requester-forced-fail",
          hold_id: "hold-forced-fail",
          release_reason: "forced-failure regression test"
        },
        tenant: org_id
      )
      |> Ash.create!(authorize?: false)

    assert {:error, _error} =
             record
             |> Ash.Changeset.for_update(:approve, %{approved_by: "owner-forced-fail"}, tenant: org_id)
             |> Ash.update(authorize?: false)

    reloaded =
      ApprovalLegalHoldRelease
      |> Ash.Query.filter(id == ^record.id)
      |> Ash.Query.for_read(:read, %{}, tenant: org_id, authorize?: false)
      |> Ash.read_one!()

    assert reloaded.approved_by == nil,
           "a real forced AuditLogEntry write failure must roll back approved_by too -- " <>
             "this is exactly the after_transaction/2 bug the after_action/2 fix targets"

    assert audit_entries_for(record.id) == [],
           "expected no real AuditLogEntry row to survive the real rolled-back transaction"
  end
end
