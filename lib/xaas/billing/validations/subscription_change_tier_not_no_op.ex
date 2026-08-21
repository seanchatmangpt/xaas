defmodule Xaas.Billing.Validations.SubscriptionChangeTierNotNoOp do
  @moduledoc """
  Real business rule for `Xaas.Billing.Subscription`'s `:change_tier` update
  action: rejects a `:change_tier` call whose new `:tier` argument equals
  the subscription's real current (pre-change) tier
  (`changeset.data.tier`, the same "check the changeset's from-state"
  discipline `Xaas.Billing.Changes.SubscriptionChargeOnActivate` documents
  for its own idempotency check). A same-tier "change" has nothing real to
  prorate -- no `Xaas.Ledger.Transfer` should be created, and the request is
  a real 400-shaped rejection rather than a silent no-op success.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    new_tier = Ash.Changeset.get_argument(changeset, :tier)
    current_tier = changeset.data.tier

    if new_tier == current_tier do
      {:error, field: :tier, message: "is already #{current_tier} -- nothing to change or prorate"}
    else
      :ok
    end
  end
end
