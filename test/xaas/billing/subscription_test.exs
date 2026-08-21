defmodule Xaas.Billing.SubscriptionTest do
  @moduledoc """
  Real Chicago-style tests: real Ash.create!/Ash.get! against the real
  sandboxed Postgres (Xaas.Repo), asserting on real persisted state. No
  mocking of the resource, its unique identity, or the DB. Exercises the
  one plan tier this resource is scoped to prove end-to-end
  (`:tier` fixed to `:standard`) using a real-shaped Stripe test-mode id
  string (not a real network call to Stripe -- this resource's own scope
  is the persisted row, not the Stripe API call itself; see the
  resource's moduledoc for what's deliberately out of scope).
  """
  use Kanban.DataCase

  alias Xaas.Billing.Subscription

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org_id, do: "org-#{System.unique_integer([:positive])}"

  test "creates a real standard-tier subscription row with default status" do
    org = org_id()

    subscription =
      Subscription
      |> Ash.Changeset.for_create(:create, %{
        org_id: org,
        stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}"
      })
      |> Ash.create!(authorize?: false)

    assert subscription.org_id == org
    assert subscription.tier == :standard
    assert subscription.status == :incomplete
    assert subscription.stripe_subscription_id == nil

    persisted = Ash.get!(Subscription, subscription.id, authorize?: false)
    assert persisted.stripe_customer_id == subscription.stripe_customer_id
  end

  test "sync_from_stripe updates status and current_period_end from real applied state" do
    org = org_id()

    subscription =
      Subscription
      |> Ash.Changeset.for_create(:create, %{
        org_id: org,
        stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
        stripe_subscription_id: "sub_test_pending"
      })
      |> Ash.create!(authorize?: false)

    period_end = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(30, :day)

    updated =
      subscription
      |> Ash.Changeset.for_update(:sync_from_stripe, %{
        stripe_subscription_id: "sub_test_active",
        status: :active,
        current_period_end: period_end
      })
      |> Ash.update!(authorize?: false)

    assert updated.status == :active
    assert updated.stripe_subscription_id == "sub_test_active"
    assert updated.current_period_end == period_end

    persisted = Ash.get!(Subscription, subscription.id, authorize?: false)
    assert persisted.status == :active
  end

  test "unique_org identity rejects a real second subscription for the same org" do
    org = org_id()

    Subscription
    |> Ash.Changeset.for_create(:create, %{
      org_id: org,
      stripe_customer_id: "cus_test_first"
    })
    |> Ash.create!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             Subscription
             |> Ash.Changeset.for_create(:create, %{
               org_id: org,
               stripe_customer_id: "cus_test_second"
             })
             |> Ash.create(authorize?: false)
  end
end
