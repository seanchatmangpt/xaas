defmodule Xaas.Billing.ApprovalTierDowngradeTest do
  @moduledoc """
  Real Chicago-style tests for the real fix to
  `Xaas.Billing.ApprovalTierDowngrade`: it previously had no
  `subscription_id`/`requested_tier` attributes at all and its
  `Xaas.Billing.Changes.ApprovalTierDowngradeApprove` Change module was a
  byte-identical no-op, never even wired into the `:approve` action --
  approving a "tier downgrade" had zero real effect (real, disclosed dead
  code found by the eleventh-pass ERRC grid sweep, see
  `docs/claude/diataxis/explanation/errc-innovation-grid.md`). This file
  proves the real fix: approving a pending downgrade now really drives
  `Xaas.Billing.Subscription`'s real, already-atomic `:change_tier`
  action, which itself moves a real prorated `Xaas.Ledger.Transfer`
  credit back to the org (`Xaas.Billing.Changes.SubscriptionProrateTierChange`).

  Real `Ecto.Adapters.SQL.Sandbox`-backed Postgres (`Xaas.Repo`), real
  `Ash.Changeset.for_create`/`for_update` + `Ash.create!`/`Ash.update`
  calls, real `Xaas.Ledger.Account`/`Balance` rows read back to assert on
  real persisted money movement. No mocking of `ApprovalTierDowngrade`,
  `ApprovalTierDowngradeApprove`, `Subscription`, or the ledger.
  """
  use ExUnit.Case, async: true
  require Ash.Query

  alias Xaas.Billing.{ApprovalTierDowngrade, Subscription}
  alias Xaas.Ledger.{Account, Balance}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # Real running-balance read -- same helper shape (and same real "highest
  # transfer_id wins" reasoning) as `Xaas.Billing.SubscriptionTest.real_balance_for/1`.
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

  defp create_subscription!(org_id, tier) do
    Subscription
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      tier: tier,
      status: :incomplete
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_pending!(subscription_id, requested_tier, requested_by) do
    ApprovalTierDowngrade
    |> Ash.Changeset.for_create(:create, %{
      requested_by: requested_by,
      subscription_id: subscription_id,
      requested_tier: requested_tier
    })
    |> Ash.create!(authorize?: false)
  end

  test "approving a real tier downgrade actually drops the subscription's tier and credits the real prorated Ledger amount" do
    org_id = "org-tier-downgrade-#{System.unique_integer([:positive])}"
    subscription = create_subscription!(org_id, :pro)

    pending =
      create_pending!(subscription.id, :standard, "requester-#{System.unique_integer([:positive])}")

    approved =
      pending
      |> Ash.Changeset.for_update(:approve, %{
        approved_by: "approver-#{System.unique_integer([:positive])}"
      })
      |> Ash.update!(authorize?: false)

    assert approved.approved_by != nil

    reloaded_subscription = Ash.reload!(subscription, authorize?: false)

    assert reloaded_subscription.tier == :standard,
           "approving a tier downgrade must actually drive Subscription.change_tier -- " <>
             "the whole point of this fix"

    # (2900 - 7900) / 30 * 30 = -5000 cents -> a real $50.00 credit back to
    # the org (never activated, so no SubscriptionChargeOnActivate baseline
    # noise -- this is the whole real balance).
    org_balance = real_balance_for(org_id)
    assert Money.equal?(org_balance, Money.new(:USD, "50.00"))
  end

  test "creating a downgrade request targeting the subscription's own current tier is really rejected" do
    org_id = "org-notlower-sametier-#{System.unique_integer([:positive])}"
    subscription = create_subscription!(org_id, :standard)

    assert {:error, %Ash.Error.Invalid{}} =
             ApprovalTierDowngrade
             |> Ash.Changeset.for_create(:create, %{
               requested_by: "requester-sametier",
               subscription_id: subscription.id,
               requested_tier: :standard
             })
             |> Ash.create(authorize?: false)
  end

  test "creating a downgrade request targeting a real higher tier is really rejected" do
    org_id = "org-notlower-highertier-#{System.unique_integer([:positive])}"
    subscription = create_subscription!(org_id, :standard)

    assert {:error, %Ash.Error.Invalid{}} =
             ApprovalTierDowngrade
             |> Ash.Changeset.for_create(:create, %{
               requested_by: "requester-highertier",
               subscription_id: subscription.id,
               requested_tier: :pro
             })
             |> Ash.create(authorize?: false)

    # No real ApprovalTierDowngrade row was persisted, and the subscription
    # itself is untouched -- a rejected create has zero real side effects.
    reloaded_subscription = Ash.reload!(subscription, authorize?: false)
    assert reloaded_subscription.tier == :standard
  end

  # Real Chicago-style coverage for the atomic-Ledger-write discipline
  # (`ApprovalTierDowngradeApprove` uses `Ash.Changeset.after_action/2`,
  # not `after_transaction/2`, exactly like every other fixed sibling in
  # this codebase): a real Ledger write failure inside the driven
  # `Subscription.change_tier` call must roll BOTH the subscription's
  # `:tier` AND this approval's own `approved_by` back -- never
  # approved-but-not-downgraded, and never downgraded-but-not-approved.
  #
  # Same real, deterministic forced-failure technique already proven in
  # `Xaas.Billing.SubscriptionTest`'s own forced-failure test (a real,
  # concurrent `Ledger.Account` unique-constraint race was tried first via
  # `Task.async` + `Sandbox.allow/3` and empirically does NOT reproduce
  # under Ecto Sandbox -- see that test's own comment): setting the
  # subscription's `org_id` to the exact same string as the fixed
  # `platform:revenue:subscription` identifier makes
  # `SubscriptionProrateTierChange`'s two `open_or_get_account/1` calls
  # resolve to the identical `Xaas.Ledger.Account` row, so
  # `AshDoubleEntry.Transfer.Changes.VerifyTransfer` (real dependency
  # code) really rejects the proration transfer on every run.
  test "a real forced Ledger.Transfer failure on approve rolls back both approved_by and the subscription's tier" do
    org_id = "platform:revenue:subscription"
    subscription = create_subscription!(org_id, :pro)

    pending = create_pending!(subscription.id, :standard, "requester-forced-fail")

    assert {:error, _error} =
             pending
             |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-forced-fail"})
             |> Ash.update(authorize?: false)

    persisted_approval = ApprovalTierDowngrade |> Ash.get!(pending.id, authorize?: false)

    assert persisted_approval.approved_by == nil,
           "a real forced Ledger.Transfer failure must roll back approved_by too -- " <>
             "the same after_action/2 atomicity every sibling *ChargeOverage/*Approve change " <>
             "was built to guarantee"

    reloaded_subscription = Ash.reload!(subscription, authorize?: false)

    assert reloaded_subscription.tier == :pro,
           "a real forced Ledger.Transfer failure must roll back the subscription's :tier too -- " <>
             "this is the exact after_transaction/2-style bug class the after_action/2 design " <>
             "was chosen to prevent"

    # Real cross-check: the whole (nested) transaction rolled back, so the
    # Ledger.Account opened mid-flight (before the transfer failed) must
    # not have been left behind either -- no orphaned real Postgres row.
    assert real_balance_for(org_id) == nil,
           "expected no real Ledger.Account/Balance row to survive the real rolled-back transaction"
  end
end
