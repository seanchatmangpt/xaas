defmodule Xaas.Billing.SubscriptionTest do
  @moduledoc """
  Real Chicago-style tests: real `Ecto.Adapters.SQL.Sandbox`-backed
  Postgres (`Xaas.Repo`), real `Ash.Changeset.for_create`/`for_update` +
  `Ash.create!`/`Ash.update!` calls against the real `billing_subscriptions`
  table, real `Xaas.Ledger.Account`/`Balance` rows read back to assert on
  real persisted money movement. No mocking of `Xaas.Billing.Subscription`,
  `Xaas.Billing.Changes.SubscriptionChargeOnActivate`, or the ledger.
  """
  use ExUnit.Case, async: true
  require Ash.Query

  alias Xaas.Billing.Subscription
  alias Xaas.Ledger.{Account, Balance}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_incomplete!(org_id) do
    Subscription
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      tier: :standard,
      status: :incomplete
    })
    |> Ash.create!(authorize?: false)
  end

  defp sync_status!(subscription, status) do
    subscription
    |> Ash.Changeset.for_update(:sync_from_stripe, %{status: status})
    |> Ash.update!(authorize?: false)
  end

  defp real_balance_for(identifier) do
    case Account |> Ash.Query.filter(identifier: identifier) |> Ash.read_one!(authorize?: false) do
      nil ->
        nil

      account ->
        Balance
        |> Ash.Query.filter(account_id: account.id)
        |> Ash.read!(authorize?: false)
        |> Enum.reduce(Money.new(:USD, 0), fn b, acc -> Money.add!(acc, b.balance) end)
    end
  end

  test "activating a subscription for the first time charges a real -$29.00 ledger fee" do
    org_id = "org-activate-#{System.unique_integer([:positive])}"
    subscription = create_incomplete!(org_id)

    subscription
    |> sync_status!(:active)

    org_balance = real_balance_for(org_id)
    revenue_balance = real_balance_for("platform:revenue:subscription")

    assert org_balance != nil,
           "expected a real Xaas.Ledger.Account/Balance to exist for #{org_id}"

    assert Money.equal?(org_balance, Money.new(:USD, "-29.00"))
    assert Money.compare!(revenue_balance, Money.new(:USD, "0")) == :gt
  end

  test "activating twice does not double-charge" do
    org_id = "org-noduplicate-#{System.unique_integer([:positive])}"
    subscription = create_incomplete!(org_id)

    activated = sync_status!(subscription, :active)

    # A second real `:sync_from_stripe` call that re-confirms (or leaves
    # unchanged) `:active` status -- e.g. a duplicate webhook replay --
    # must not charge a second real ledger fee.
    _ = sync_status!(activated, :active)

    org_balance = real_balance_for(org_id)

    assert Money.equal?(org_balance, Money.new(:USD, "-29.00")),
           "expected exactly one real -$29.00 charge, not a duplicate"
  end

  test "a status transition that never touches :active charges nothing" do
    org_id = "org-nocharge-#{System.unique_integer([:positive])}"
    subscription = create_incomplete!(org_id)

    _ = sync_status!(subscription, :past_due)

    assert real_balance_for(org_id) == nil,
           "expected no real Xaas.Ledger.Account to have been opened for #{org_id} -- never activated"
  end

  # Real AshIam read-policy coverage -- same real, working pilot pattern as
  # `Xaas.Accounts.Org` (bypass action_type(:read) do authorize_if
  # AshIam.Check end, NOT :create/:update -- disclosed as broken there in
  # this repo's ash_iam version, see this resource's policies block).

  test "an actor with a real Allow statement can read via the real AshIam.Check policy" do
    org_id = "org-iam-#{System.unique_integer([:positive])}"
    subscription = create_incomplete!(org_id)

    actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["read"], "Resource" => ["xaas:billing_subscription:*"]}
        ]
      }
    }

    results = Subscription |> Ash.read!(actor: actor)
    assert Enum.any?(results, &(&1.id == subscription.id))
  end

  test "an actor with no real iam_policy is really denied read -- not silently allowed" do
    org_id = "org-iam-hidden-#{System.unique_integer([:positive])}"
    subscription = create_incomplete!(org_id)

    results = Subscription |> Ash.read!(actor: %{})
    refute Enum.any?(results, &(&1.id == subscription.id))
  end

  test "an actor whose Allow statement names another subscription cannot read this one" do
    visible_org = "org-iam-visible-#{System.unique_integer([:positive])}"
    other_org = "org-iam-other-#{System.unique_integer([:positive])}"
    visible = create_incomplete!(visible_org)
    other = create_incomplete!(other_org)

    scoped_actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["read"], "Resource" => ["xaas:billing_subscription:#{visible.id}"]}
        ]
      }
    }

    results = Subscription |> Ash.read!(actor: scoped_actor)
    assert Enum.any?(results, &(&1.id == visible.id))
    refute Enum.any?(results, &(&1.id == other.id))
  end

  test "org_id uniqueness is really enforced" do
    org_id = "org-dup-#{System.unique_integer([:positive])}"
    create_incomplete!(org_id)

    assert {:error, %Ash.Error.Invalid{}} =
             Subscription
             |> Ash.Changeset.for_create(:create, %{
               org_id: org_id,
               stripe_customer_id: "cus_dup_#{System.unique_integer([:positive])}",
               tier: :standard,
               status: :incomplete
             })
             |> Ash.create(authorize?: false)
  end
end
