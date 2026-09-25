defmodule Xaas.Billing.Validations.ApprovalTierDowngradeTargetsLowerTier do
  @moduledoc """
  Real business rule for `Xaas.Billing.ApprovalTierDowngrade`'s `:create`
  action: `requested_tier` must be a real, strictly lower tier than the
  target `Xaas.Billing.Subscription`'s real current `:tier` -- a "tier
  downgrade" request naming an equal or higher tier is not a downgrade at
  all and is rejected as a real 400-shaped error, matching this codebase's
  `Xaas.Billing.Validations.SubscriptionChangeTierNotNoOp` discipline of
  rejecting a no-op/wrong-direction tier change at the API boundary rather
  than silently accepting it.

  Tier rank is the same ascending `:standard` < `:pro` < `:enterprise`
  ordering `Xaas.Billing.Changes.SubscriptionProrateTierChange`'s own
  placeholder monthly pricing uses (cheapest to priciest).
  """
  use Ash.Resource.Validation

  @tier_rank %{standard: 0, pro: 1, enterprise: 2}

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    subscription_id = Ash.Changeset.get_attribute(changeset, :subscription_id)
    requested_tier = Ash.Changeset.get_attribute(changeset, :requested_tier)

    # Defer to the real `allow_nil? false` required-attribute checks for
    # either missing value -- this validation only judges the real
    # relationship between the two once both are actually present.
    if is_nil(subscription_id) or is_nil(requested_tier) do
      :ok
    else
      check_lower_tier(subscription_id, requested_tier)
    end
  end

  defp check_lower_tier(subscription_id, requested_tier) do
    case Ash.get(Xaas.Billing.Subscription, subscription_id, authorize?: false) do
      {:ok, %{tier: current_tier}} ->
        if Map.fetch!(@tier_rank, requested_tier) < Map.fetch!(@tier_rank, current_tier) do
          :ok
        else
          {:error,
           field: :requested_tier,
           message:
             "must be a real lower tier than the subscription's current tier (#{current_tier}), not #{requested_tier}"}
        end

      {:error, _error} ->
        {:error, field: :subscription_id, message: "does not reference a real subscription"}
    end
  end
end
