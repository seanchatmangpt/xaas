defmodule Xaas.Billing.Validations.SubscriptionStripeTransitionAllowed do
  @moduledoc """
  W897 (w729 `UNSUPPORTED(lifecycle-state-machine)` repair): a real
  `Ash.Resource.Validation` on `Xaas.Billing.Subscription`'s
  `:sync_from_stripe` refusing any `{current, new}` status edge not in an
  explicit allow-list, instead of accepting any in-enum status from any
  prior status unconditionally.

  House idiom mirror (per w891 triage row 5): `Xaas.Ultracode.Validations.
  RunTransitionAllowed` / `Xaas.A2a.Validations.ForwardOnlyTransition`
  (W772) — explicit allow-list, typed `InvalidChanges` refusal.

  Allow-listed edges, and why each is real:

  - Self-transitions `{s, s}` for every status — Stripe redelivers events
    at-least-once (see the webhook controller's Actuation-replay test); a
    redelivered `customer.subscription.updated` must not be refused.
  - `:incomplete -> :active` — completed payment method (the resource's
    own attribute comment names this edge).
  - `:incomplete -> :past_due` — a real `invoice.payment_failed` on a
    fresh incomplete subscription (exercised by
    `test/xaas/billing/subscription_test.exs` line 119's
    "never touches :active" court).
  - `:incomplete -> :canceled` — `customer.subscription.deleted` before
    first activation (exercised by the deepening suite's canceled court).
  - `:active -> :past_due` — `invoice.payment_failed` (webhook controller
    court + the resource's own attribute comment).
  - `:active -> :canceled` — `customer.subscription.deleted`.
  - `:past_due -> :active` — recovery payment after dunning.
  - `:past_due -> :canceled` — cancellation during dunning.

  **Terminal-is-terminal**: no edge leaves `:canceled` — a canceled
  subscription can never be re-activated through `:sync_from_stripe`.
  This is the exact edge w729's pin witnessed (`:canceled -> :active`
  accepted). The webhook controller's moduledoc already documents the
  real replacement-subscription path (a fresh Checkout after a deleted
  event produces a NEW `stripe_subscription_id` on the same row) — that
  is a designed follow-up decision (scoped re-activation keyed on a
  changing stripe id), deliberately not smuggled into this allow-list.
  """

  use Ash.Resource.Validation

  @statuses [:incomplete, :active, :past_due, :canceled]

  @allowed_edges (
    self = for s <- @statuses, do: {s, s}
    forward = [
      {:incomplete, :active},
      {:incomplete, :past_due},
      {:incomplete, :canceled},
      {:active, :past_due},
      {:active, :canceled},
      {:past_due, :active},
      {:past_due, :canceled}
    ]

    self ++ forward
  )

  @impl true
  def validate(changeset, _opts, _context) do
    current = Ash.Changeset.get_data(changeset, :status)
    new = Ash.Changeset.get_attribute(changeset, :status)

    if {current, new} in @allowed_edges do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidChanges.exception(
         message:
           "stripe subscription transition #{inspect(current)} -> #{inspect(new)} is not an " <>
             "admitted edge (canceled is terminal; allowed: #{inspect(@allowed_edges)})"
       )}
    end
  end
end
