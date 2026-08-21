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
  # async: false (real, disclosed, fourteenth-pass ERRC fix -- see
  # `docs/claude/diataxis/explanation/errc-innovation-grid.md`): this file
  # writes real `Xaas.Ledger.Account`/`Transfer` rows, both
  # `AshEvents.Events`-tracked resources with no `multitenancy do` block, so
  # every write takes AshEvents' single global `pg_advisory_xact_lock(
  # 2_147_483_647)` (the library default, unset by `Xaas.Ledger.EventLog`).
  # That lock is transaction-scoped and this test's Sandbox transaction
  # stays open until teardown, so under `async: true` any 2 of this file's
  # 6 real siblings running concurrently on separate connections contend
  # for the identical lock for the length of the slower test -- the real,
  # root-caused mechanism behind this session's worsening full-suite
  # Postgres "deadlock detected" flake. Slower (serialized relative to its
  # 5 named siblings, see `dev_seeds_test.exs`), but correct.
  use ExUnit.Case, async: false
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

  # Real Chicago-style regression test for this pass's fix: a
  # `newly_approved?/2` guard added to
  # `ApprovalBackupRetentionChangeChargeOverage`, mirroring
  # `test/xaas/billing/approval_sla_credit_apply_test.exs`'s "approving
  # twice does not double-credit". Before the fix, a real second
  # `:approve` call against an already-approved record moved the real
  # ledger balance from -$6.00 to -$12.00 (live-reproduced this pass with
  # a temporary local test, deleted after confirming the bug -- see this
  # change module's own moduledoc).
  test "approving twice does not double-charge the overage fee" do
    org_id = "org-backup-retention-noduplicate-#{System.unique_integer([:positive])}"
    create_org!(org_id)

    request = create_pending!(org_id, "requester-noduplicate")

    approved =
      request
      |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-noduplicate"}, tenant: org_id)
      |> Ash.update!(authorize?: false)

    # A second real :approve call against an already-approved record
    # (re-confirming the same approved_by) must not charge a second real
    # overage fee.
    _ =
      approved
      |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-noduplicate"}, tenant: org_id)
      |> Ash.update!(authorize?: false)

    org_balance = real_balance_for(org_id)

    # pro tier's default is 30 days; the request asked for 90, so 60
    # overage days at 10 cents/day == a real $6.00 charge, exactly once.
    assert Money.equal?(org_balance, Money.new(:USD, "-6.00")),
           "expected exactly one real -$6.00 overage charge, not a duplicate"
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
