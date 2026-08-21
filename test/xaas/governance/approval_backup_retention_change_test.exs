defmodule Xaas.Governance.ApprovalBackupRetentionChangeTest do
  @moduledoc """
  Real Chicago-style regression test for the one real money/audit-moving
  `after_action/2` write on this resource
  (`Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`)
  that had zero unit-test coverage of its own atomicity before this file
  existed -- only a controller test (happy-path + no-overage cases,
  `test/kanban_web/controllers/approval_backup_retention_change_controller_test.exs`)
  and a stress test (deliberately tuned to avoid any overage at all, see
  `approval_backup_retention_change_stress_test.exs`'s own moduledoc)
  touch this resource. Real `Ecto.Adapters.SQL.Sandbox`-backed Postgres
  (`Xaas.Repo`), real `Ash.Changeset.for_create`/`for_update` +
  `Ash.create!`/`Ash.update` calls, real `Xaas.Ledger.Account`/`Balance`
  rows read back. No mocking of `ApprovalBackupRetentionChange`,
  `ApprovalBackupRetentionChangeChargeOverage`, or the ledger.

  Same real, deterministic forced-failure technique already proven in
  `test/xaas/billing/approval_sla_credit_apply_test.exs` (see that
  file's own comment for why a genuine concurrent `Ledger.Account` race
  does not reproduce under Ecto Sandbox's testing model):
  `AshDoubleEntry.Transfer.Changes.VerifyTransfer` (real dependency
  code, `deps/ash_double_entry/lib/transfer/changes/verify_transfer.ex`)
  really rejects any `:transfer` whose `from_account_id` equals its
  `to_account_id`. `ApprovalBackupRetentionChangeChargeOverage.charge_overage/2`
  calls `open_or_get_account/1` once for `record.org_id` and once for the
  fixed `@platform_revenue_account_identifier`
  (`"platform:revenue:backup-retention-overage"`) -- using that exact
  string as this test's `org_id` makes both calls resolve to the
  identical `Xaas.Ledger.Account` row, deterministically tripping
  `VerifyTransfer`'s real rejection on every run.

  One real difference from the SLA-credit sibling this test had to
  account for: unlike `Xaas.Billing.ApprovalSlaCreditApply`, this
  resource's `org_id` is a real FK to `Xaas.Accounts.Org.slug`
  (attribute-strategy multitenancy, `global? false` -- see
  `Xaas.Governance.ApprovalBackupRetentionChange`'s own `multitenancy`
  block), so the forced-failure `org_id` has to be a real, persisted
  `Org.slug`, not just a bare string. `Org.slug` has no format
  constraint (a plain unique string -- see `Xaas.Accounts.Org`'s
  `identities`), so the identical identifier string still works as both
  the real `Org.slug`/tenant and the real `Ledger.Account` identifier.
  """
  use ExUnit.Case, async: true
  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalBackupRetentionChange
  alias Xaas.Ledger.{Account, Balance}

  @platform_revenue_account_identifier "platform:revenue:backup-retention-overage"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # Real running-balance read, same helper shape (and same real
  # "highest transfer_id wins" reasoning) as
  # `Xaas.Billing.ApprovalSlaCreditApplyTest.real_balance_for/1`.
  defp real_balance_for(identifier) do
    case Account |> Ash.Query.filter(identifier: identifier) |> Ash.read_one!(authorize?: false) do
      nil ->
        nil

      account ->
        Balance
        |> Ash.Query.filter(account_id: account.id)
        |> Ash.read!(authorize?: false)
        |> Enum.max_by(& &1.transfer_id, fn -> nil end)
        |> case do
          nil -> nil
          balance -> balance.balance
        end
    end
  end

  defp create_org!(slug) do
    Org
    |> Ash.Changeset.for_create(:create, %{name: "Forced-Fail Org", slug: slug})
    |> Ash.create!(authorize?: false)
  end

  defp create_pending!(org_id, requested_by) do
    ApprovalBackupRetentionChange
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: org_id,
        requested_by: requested_by,
        # pro tier's real default is 30 days
        # (ApprovalBackupRetentionChangeChargeOverage's @default_days);
        # 90 is within pro's real 7-90 range
        # (ApprovalBackupRetentionChangeWithinTierRange) and 60 days
        # above that default, so charge_overage/2's `overage_days > 0`
        # branch really fires on :approve -- same numbers already
        # exercised (non-forced-failure) by the controller test's
        # "approving a change that exceeds the tier default charges a
        # real ledger overage fee".
        requested_retention_days: 90,
        tier: :pro
      },
      tenant: org_id
    )
    |> Ash.create!(authorize?: false)
  end

  test "a real forced Ledger.Transfer failure on overage-charge rolls back approved_by too -- never approved-but-uncharged" do
    org_id = @platform_revenue_account_identifier
    create_org!(org_id)

    request = create_pending!(org_id, "requester-forced-fail")

    assert {:error, _error} =
             request
             |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-forced-fail"})
             |> Ash.update(authorize?: false)

    persisted =
      ApprovalBackupRetentionChange |> Ash.get!(request.id, authorize?: false, tenant: org_id)

    assert persisted.approved_by == nil,
           "a real forced Ledger.Transfer failure must roll back approved_by too -- " <>
             "the same after_action/2 atomicity every sibling *ChargeOverage/*Approve change " <>
             "was built to guarantee"

    # Real cross-check: the whole parent transaction rolled back, so the
    # Ledger.Account opened mid-flight (before the transfer failed) must
    # not have been left behind either -- no orphaned real Postgres row.
    assert real_balance_for(org_id) == nil,
           "expected no real Ledger.Account/Balance row to survive the real rolled-back transaction"
  end
end
