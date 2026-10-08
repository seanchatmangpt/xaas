defmodule Xaas.Billing.SubscriptionResourceCourtW984jxTest do
  @moduledoc """
  Lane W984jx unclaimed-family probe court — the resource's own action
  layer minus the already-courted `change_tier`/atomic-retrofit sites
  (W984cc/W984fr/DD territory, not restated here).

  Census dispositions (see docs/sjira/v26.10.6/plans/w984jx-probe.md):

  - `:create` happy path, defaults, `unique_org`, `AshIam` read floor,
    `sync_from_stripe` status state machine (all admitted AND refusal
    edges), `change_tier` proration/no-op/clamp, activation-charge
    idempotency -- COVERED (subscription_test.exs,
    subscription_stripe_transition_court_w984dp_test.exs,
    subscription_tier_proration_depth_w984dd_test.exs,
    billing_deepening_test.exs, billing_multitenancy_court_test.exs).
  - UNCOVERED state-bearing residue, this file:
      1. `:create` with the full Stripe identity: the nullable
         `stripe_subscription_id` + typed `current_period_end` accepted
         set, round-tripped through real Postgres.
      2. `:create` `allow_nil?(false)` floor on `stripe_customer_id` --
         the typed refusal, and no row.
      3. `:sync_from_stripe`'s accepted NON-status fields
         (`stripe_subscription_id`, `current_period_end`): the
         applyStripeEvent / replacement-subscription write surface. No
         test in the repo passes either field to this action -- every
         existing court passes only `%{status: ...}`.
      4. `:change_tier`'s argument `one_of` constraint (`:tier` arg is
         `constraints(one_of: [...])`, so an out-of-family tier is a
         typed argument refusal BEFORE any validation/change runs).

  Chicago-style: real sandboxed Postgres, real Ash actions, real typed
  refusals, zero mocks. Per-test mutation rationale inline.
  """
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Billing.Subscription

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_changeset(attrs) do
    Subscription
    |> Ash.Changeset.for_create(:create, attrs)
  end

  defp create_minimal!(org_suffix) do
    Subscription
    |> Ash.Changeset.for_create(:create, %{
      org_id: "org-w984jx-#{org_suffix}-#{System.unique_integer([:positive])}",
      stripe_customer_id: "cus_w984jx_#{System.unique_integer([:positive])}",
      tier: :standard,
      status: :incomplete
    })
    |> Ash.create!(authorize?: false)
  end

  test "create persists the full Stripe identity: nullable stripe_subscription_id and typed current_period_end round-trip through real Postgres" do
    # Mutation rationale: deleting :stripe_subscription_id / :current_period_end
    # from :create's accept list (or untyping the column) flips this RED --
    # the accepted-set and the utc_datetime column type are the code under
    # test. Existing coverage only ever mints rows with both nil (defaults
    # court), so this accepted-set branch is unwitnessed.
    org_id = "org-w984jx-full-#{System.unique_integer([:positive])}"
    period_end = DateTime.add(DateTime.utc_now(), 30, :day) |> DateTime.truncate(:second)

    {:ok, sub} =
      create_changeset(%{
        org_id: org_id,
        stripe_customer_id: "cus_w984jx_full_#{System.unique_integer([:positive])}",
        stripe_subscription_id: "sub_w984jx_#{System.unique_integer([:positive])}",
        tier: :standard,
        status: :incomplete,
        current_period_end: period_end
      })
      |> Ash.create(authorize?: false)

    assert %Subscription{} = sub
    assert sub.stripe_subscription_id =~ ~r/^sub_w984jx_\d+$/
    # Real typed Postgres column: the utc_datetime round-trips at second
    # precision, not a free string.
    assert DateTime.compare(sub.current_period_end, period_end) == :eq

    reloaded = Ash.reload!(sub, authorize?: false)
    assert reloaded.stripe_subscription_id == sub.stripe_subscription_id
    assert DateTime.compare(reloaded.current_period_end, period_end) == :eq
  end

  test "create without stripe_customer_id is refused by the allow_nil?(false) floor -- typed InvalidAttribute, no row" do
    # Mutation rationale: relaxing stripe_customer_id's allow_nil?(false)
    # (or dropping it from the accept list making it a silently-skipped
    # required field) flips this RED. No existing court drives a create
    # missing a required attribute on this resource.
    org_id = "org-w984jx-norow-#{System.unique_integer([:positive])}"

    assert {:error, %Ash.Error.Invalid{} = invalid} =
             create_changeset(%{
               org_id: org_id,
               tier: :standard,
               status: :incomplete
             })
             |> Ash.create(authorize?: false)

    # Typed refusal: the error names the real required field.
    assert [%{field: :stripe_customer_id} = err] = invalid.errors
    assert Exception.message(err) =~ "is required"

    # Real state: no row survived the refusal.
    assert Subscription
           |> Ash.Query.filter(org_id: org_id)
           |> Ash.read!(authorize?: false) == []
  end

  test "sync_from_stripe applies non-status fields: a replacement stripe_subscription_id and a new current_period_end really persist" do
    # Mutation rationale: removing :stripe_subscription_id /
    # :current_period_end from :sync_from_stripe's accept list flips this
    # RED -- this is the applyStripeEvent write surface (a
    # customer.subscription.deleted followed by a fresh Checkout
    # re-points the stripe id; a renewal advances the period end). Every
    # existing court passes only %{status: ...}, so this accepted-field
    # branch of the real webhook-receiver target is unwitnessed.
    subscription = create_minimal!("repoint")

    new_sub_id = "sub_replacement_#{System.unique_integer([:positive])}"
    new_period_end = DateTime.add(DateTime.utc_now(), 60, :day) |> DateTime.truncate(:second)

    {:ok, synced} =
      subscription
      |> Ash.Changeset.for_update(:sync_from_stripe, %{
        stripe_subscription_id: new_sub_id,
        current_period_end: new_period_end
      })
      |> Ash.update(authorize?: false)

    # Status untouched (the self-edge {incomplete, incomplete} admits);
    # only the identity/period fields moved.
    assert synced.status == :incomplete
    assert synced.stripe_subscription_id == new_sub_id
    assert DateTime.compare(synced.current_period_end, new_period_end) == :eq

    reloaded = Ash.reload!(subscription, authorize?: false)
    assert reloaded.stripe_subscription_id == new_sub_id
    assert reloaded.status == :incomplete
    assert DateTime.compare(reloaded.current_period_end, new_period_end) == :eq
  end

  test "change_tier with an out-of-family tier argument is refused by the one_of constraint before any validation or proration runs" do
    # Mutation rationale: widening the argument's one_of constraint (or
    # dropping it) flips this RED. Note this is the ARGUMENT constraint
    # (:tier is an argument on :change_tier, not an accepted attribute
    # there), so the refusal is an InvalidArgument-class typed error --
    # distinct from SubscriptionChangeTierNotNoOp (already courted) and
    # from SubscriptionProrateTierChange (never reached here).
    subscription = create_minimal!("constraint")

    assert {:error, %Ash.Error.Invalid{}} =
             subscription
             |> Ash.Changeset.for_update(:change_tier, %{tier: :free})
             |> Ash.update(authorize?: false)

    # Real state: tier unchanged.
    reloaded = Ash.reload!(subscription, authorize?: false)
    assert reloaded.tier == :standard
  end
end
