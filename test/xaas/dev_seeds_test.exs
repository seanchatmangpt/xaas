defmodule Xaas.DevSeedsTest do
  @moduledoc """
  Real Chicago-style tests for `Xaas.DevSeeds` (the ERRC grid's twelfth-pass
  CREATE item -- `docs/claude/diataxis/explanation/errc-innovation-grid.md`,
  item 11): real `Ecto.Adapters.SQL.Sandbox`-backed Postgres (`Xaas.Repo`),
  real `Ash.Changeset.for_create`/`for_update` + `Ash.create!`/`Ash.update!`
  calls through the real `Xaas.DevSeeds.run/0` and
  `Xaas.DevSeeds.approve_seeded_pending!/0` functions, real
  `Xaas.Accounts.Org` / `Xaas.Billing.Subscription` /
  `Xaas.Ledger.Account`/`Balance` / `Xaas.Governance.ApprovalBackupRetentionChange`
  rows read back and asserted on for real persisted state. No mocking of
  `Xaas.DevSeeds` or any of the four resources it seeds.
  """
  # async: false (real, disclosed, fourteenth-pass ERRC fix -- see
  # `docs/claude/diataxis/explanation/errc-innovation-grid.md`): this file
  # writes real `Xaas.Ledger.Account`/`Transfer` rows via `DevSeeds`, both
  # `AshEvents.Events`-tracked resources with no `multitenancy do` block, so
  # every write takes AshEvents' single global `pg_advisory_xact_lock(
  # 2_147_483_647)` (the library default, unset by `Xaas.Ledger.EventLog`).
  # That lock is transaction-scoped and this test's Sandbox transaction
  # stays open until teardown, so under `async: true` any 2 of this file's
  # 6 real siblings running concurrently on separate connections contend
  # for the identical lock for the length of the slower test -- the real,
  # root-caused mechanism behind this session's worsening full-suite
  # Postgres "deadlock detected" flake. Slower (serialized relative to its
  # 5 named siblings below), but correct.
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalBackupRetentionChange
  alias Xaas.Ledger.{Account, Balance}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # Real running-balance read, same helper shape as
  # `Xaas.Billing.SubscriptionTest.real_balance_for/1` /
  # `Xaas.Governance.ApprovalBackupRetentionChangeTest.real_balance_for/1`.
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

  test "run/0 seeds a real, connected fixture chain: org -> subscription -> ledger account -> pending approval" do
    fixtures = Xaas.DevSeeds.run()

    assert %Org{name: "Acme Dev Org", slug: "acme-dev"} = fixtures.org

    assert fixtures.subscription.org_id == fixtures.org.slug
    assert fixtures.subscription.tier == :standard
    assert fixtures.subscription.status == :active

    assert fixtures.ledger_account.identifier == fixtures.org.slug
    assert fixtures.ledger_account.currency == "USD"

    assert fixtures.pending_approval.org_id == fixtures.org.slug
    assert fixtures.pending_approval.approved_by == nil
    assert fixtures.pending_approval.tier == :pro
    assert fixtures.pending_approval.requested_retention_days == 45

    # Real cross-check against the real Postgres rows, not just the
    # in-memory struct `run/0` returned.
    persisted_org = Org |> Ash.Query.filter(slug: "acme-dev") |> Ash.read_one!(authorize?: false)
    assert persisted_org.id == fixtures.org.id

    persisted_approval =
      ApprovalBackupRetentionChange
      |> Ash.get!(fixtures.pending_approval.id, authorize?: false, tenant: fixtures.org.slug)

    assert persisted_approval.approved_by == nil
  end

  test "run/0 is idempotent -- a second real call reuses the same rows instead of duplicating them" do
    first = Xaas.DevSeeds.run()
    second = Xaas.DevSeeds.run()

    assert first.org.id == second.org.id
    assert first.subscription.id == second.subscription.id
    assert first.ledger_account.id == second.ledger_account.id
    assert first.pending_approval.id == second.pending_approval.id

    real_org_count =
      Org
      |> Ash.Query.filter(slug: "acme-dev")
      |> Ash.read!(authorize?: false)
      |> length()

    assert real_org_count == 1,
           "expected exactly one real Org row for the idempotent seed slug, got #{real_org_count}"
  end

  test "approve_seeded_pending!/0 real-approves the pending row and charges a real atomic Ledger overage fee" do
    approved = Xaas.DevSeeds.approve_seeded_pending!()

    assert approved.approved_by == "dev-seed-approver@example.com"

    # :pro tier's real default is 30 days (see
    # Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage);
    # the seeded 45 requested days is 15 days over, at $0.10/day = $1.50 --
    # a real Ledger.Transfer this approval's own after_action/2 change
    # charges from the org's real Ledger.Account to the platform revenue
    # account, in the same real transaction as the approval itself.
    org_balance = real_balance_for("acme-dev")
    revenue_balance = real_balance_for("platform:revenue:backup-retention-overage")

    assert org_balance != nil,
           "expected a real Xaas.Ledger.Account/Balance to exist for the seeded org"

    assert Money.equal?(org_balance, Money.new(:USD, "-1.50"))
    assert Money.compare!(revenue_balance, Money.new(:USD, "0")) == :gt
  end
end
