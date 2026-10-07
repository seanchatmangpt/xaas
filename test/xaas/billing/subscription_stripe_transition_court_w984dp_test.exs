defmodule Xaas.Billing.SubscriptionStripeTransitionCourtW984dpTest do
  @moduledoc """
  Lane W984dp burn-down court — the uncovered refusal branch of
  `Xaas.Billing.Validations.SubscriptionStripeTransitionAllowed` (W897,
  the w729 `UNSUPPORTED(lifecycle-state-machine)` repair).

  Census finding: every *admitted* edge of the Stripe status state
  machine is witnessed indirectly (subscription_test's happy paths, the
  stripe webhook controller court), but no test anywhere drives an
  *illegal* edge through `:sync_from_stripe` — the
  terminal-is-terminal law (`:canceled` can never be re-activated) and
  the typed `InvalidChanges` refusal are unwitnessed. This court is the
  falsifier for that validation: deleting it, or adding a
  `{:canceled, _}` forward edge to the allow-list, flips these tests
  RED. Chicago-style: real sandboxed Postgres, real Ash actions, real
  typed refusals — zero mocks.

  Per-test mutation rationale is stated inline at each test.
  """
  use ExUnit.Case, async: false

  alias Xaas.Billing.Subscription

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_with_status!(status) do
    Subscription
    |> Ash.Changeset.for_create(:create, %{
      org_id: "org-w984dp-#{System.unique_integer([:positive])}",
      stripe_customer_id: "cus_w984dp_#{System.unique_integer([:positive])}",
      tier: :standard,
      status: status
    })
    |> Ash.create!(authorize?: false)
  end

  defp sync(subscription, status) do
    subscription
    |> Ash.Changeset.for_update(:sync_from_stripe, %{status: status})
    |> Ash.update(authorize?: false)
  end

  defp reloaded(subscription), do: Ash.reload!(subscription, authorize?: false)

  test "the terminal-is-terminal law: a :canceled subscription refuses re-activation through :sync_from_stripe (the exact edge w729's pin witnessed accepted)" do
    canceled = create_with_status!(:canceled)

    assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.InvalidChanges{} = error]}} =
             sync(canceled, :active)

    # The typed refusal names the real edge and the terminal law, and the
    # real row keeps its terminal status -- refusal, not silent accept.
    assert Exception.message(error) =~ "not an admitted edge"
    assert Exception.message(error) =~ ":canceled -> :active"
    assert reloaded(canceled).status == :canceled
  end

  test "terminal-is-terminal is total: every non-self target from :canceled is refused, and only the redelivery self-edge admits" do
    canceled = create_with_status!(:canceled)

    for target <- [:incomplete, :active, :past_due] do
      assert {:error, %Ash.Error.Invalid{}} = sync(canceled, target),
             "canceled -> #{inspect(target)} must be refused (no edge leaves :canceled)"
    end

    # Stripe redelivers at-least-once: the {canceled, canceled} self-edge
    # must stay admitted even though nothing else leaves :canceled.
    assert {:ok, still} = sync(canceled, :canceled)
    assert still.status == :canceled
    assert reloaded(canceled).status == :canceled
  end

  test "every admitted self-edge accepts a redelivered webhook for all four statuses" do
    for status <- [:incomplete, :active, :past_due, :canceled] do
      subscription = create_with_status!(status)

      assert {:ok, updated} = sync(subscription, status),
             "self-edge #{inspect(status)} -> #{inspect(status)} must admit (at-least-once redelivery)"

      assert updated.status == status
    end
  end

  test "the admitted dunning cycle is real: :active -> :past_due -> :active recovery, and the down-edge into dunning, both admit" do
    subscription = create_with_status!(:incomplete)

    assert {:ok, past_due} = sync(subscription, :past_due)

    assert {:ok, recovered} = sync(past_due, :active)

    # And the forward edge back into dunning still admits after recovery.
    assert {:ok, dunning_again} = sync(recovered, :past_due)
    assert dunning_again.status == :past_due
  end

  test "an illegal forward edge between two non-terminal statuses is refused with the typed InvalidChanges and no partial state" do
    # :incomplete -> :canceled is admitted; but {:active, :incomplete} is
    # not in the allow-list (no un-cancel edge, no rewind into
    # incomplete) -- the exact shape of an out-of-enum-order Stripe replay.
    subscription = create_with_status!(:active)

    assert {:error,
            %Ash.Error.Invalid{
              errors: [%Ash.Error.Changes.InvalidChanges{message: message}]
            }} = sync(subscription, :incomplete)

    assert message =~ ":active -> :incomplete"
    assert message =~ "not an admitted edge"

    # Real state: the row is untouched by the refused transition.
    assert reloaded(subscription).status == :active
  end
end
