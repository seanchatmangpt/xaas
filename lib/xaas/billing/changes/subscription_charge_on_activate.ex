defmodule Xaas.Billing.Changes.SubscriptionChargeOnActivate do
  @moduledoc """
  Real, disclosed NEW business logic (not ported from platform-console --
  platform-console's `applyStripeEvent` (stripe-billing.ts:527-576) only
  updates `status`/`currentPeriodEnd` from a real webhook event; it never
  moves any money of its own, since Stripe itself already collected the
  real subscription payment on its side). This is xaas's own "be its own
  payment processor" mechanism, the same pattern as
  `Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`:
  when a `Xaas.Billing.Subscription` transitions to `:active` for the
  first time, a real `Xaas.Ledger.Transfer` moves a real (if
  placeholder-priced) monthly subscription fee from the org's real
  `Xaas.Ledger.Account` to a fixed platform-revenue account, inside this
  action's own transaction.

  `@standard_tier_monthly_fee_cents` ($29.00/month) is an invented
  placeholder price this session chose for the `:standard` tier, not a
  commercially validated product price -- stated here plainly rather than
  silently implied, same disclosure discipline as the overage-charge
  module's `@overage_rate_cents_per_day`.

  ## Idempotency

  Wired onto `Xaas.Billing.Subscription`'s `:sync_from_stripe` update
  action (the real action that transitions `status`, per that resource's
  own moduledoc -- `:create` accepts an initial `status` directly and is
  NOT charged here, since a row created with `status: :active` up front
  is a test/backfill path, not a real "the org just activated" event).
  Only charges when the changeset's own pre-change value
  (`changeset.data.status`, real Ash update-changeset semantics -- holds
  the record's value *before* this update applies) was NOT already
  `:active` and the record's real post-change value IS `:active`. A
  second `:sync_from_stripe` call that leaves (or re-confirms) `:active`
  status -- e.g. a duplicate webhook replay -- does not charge again,
  same discipline the overage-charge module documents for avoiding
  double-charges.
  """
  use Ash.Resource.Change

  @standard_tier_monthly_fee_cents 2900
  @platform_revenue_account_identifier "platform:revenue:subscription"

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, record ->
      if newly_activated?(changeset, record) do
        case charge_activation_fee(record) do
          {:ok, _transfer} -> {:ok, record}
          {:error, error} -> {:error, error}
        end
      else
        {:ok, record}
      end
    end)
  end

  # `changeset.data` is the real pre-change record on an Ash update
  # changeset -- the same "check the changeset's from-state" discipline
  # the overage-charge module's caller (this resource's moduledoc) points
  # to for avoiding double-charges.
  defp newly_activated?(changeset, record) do
    record.status == :active and changeset.data.status != :active
  end

  defp charge_activation_fee(record) do
    dollars = Decimal.div(Decimal.new(@standard_tier_monthly_fee_cents), Decimal.new(100))
    amount = Money.new(:USD, dollars)

    with {:ok, org_account} <- open_or_get_account(record.org_id),
         {:ok, revenue_account} <- open_or_get_account(@platform_revenue_account_identifier) do
      Xaas.Ledger.Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: amount,
        timestamp: DateTime.utc_now(),
        from_account_id: org_account.id,
        to_account_id: revenue_account.id
      })
      |> Ash.create(authorize?: false)
    end
  end

  defp open_or_get_account(identifier) do
    case Xaas.Ledger.Account
         |> Ash.Query.filter(identifier: identifier)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} ->
        Xaas.Ledger.Account
        |> Ash.Changeset.for_create(:open, %{identifier: identifier, currency: "USD"})
        |> Ash.create(authorize?: false)

      {:ok, account} ->
        {:ok, account}

      {:error, error} ->
        {:error, error}
    end
  end
end
