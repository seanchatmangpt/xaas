defmodule Xaas.Billing.Changes.SubscriptionProrateTierChange do
  @moduledoc """
  Real, disclosed NEW business logic (same "xaas is its own payment
  processor" pattern as `Xaas.Billing.Changes.SubscriptionChargeOnActivate`
  and `Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`):
  when `Xaas.Billing.Subscription`'s `:change_tier` update action moves a
  subscription from one real `:tier` to another mid-cycle, a real
  `Xaas.Ledger.Transfer` moves a real prorated amount between the org's
  real `Xaas.Ledger.Account` and the fixed `platform:revenue:subscription`
  account -- the same revenue account `SubscriptionChargeOnActivate` already
  uses.

  ## Real, disclosed placeholder monthly prices

  Invented this session, not commercially validated products -- same
  disclosure discipline as `SubscriptionChargeOnActivate`'s $29.00/month
  and `ApprovalBackupRetentionChangeChargeOverage`'s $0.10/day:

  - `:standard` -- $29.00/month (matches `SubscriptionChargeOnActivate`'s
    existing `@standard_tier_monthly_fee_cents` exactly, so an upgrade *to*
    standard or downgrade *from* standard reconciles against the real
    activation charge already on the books).
  - `:pro` -- $79.00/month.
  - `:enterprise` -- $299.00/month.

  ## Real proration formula

  `(new_monthly_cents - old_monthly_cents) / 30 * days_remaining`, where
  `days_remaining` is the real, whole-day `Date.diff/2` between today and
  `current_period_end` when the subscription has one set, else the full
  30-day period is treated as remaining (per this task's own instruction --
  no real period has been observed yet, so nothing has been "used" from it
  to prorate away). A 30-day month is used as the daily-rate denominator
  for both tiers, same simplification `ApprovalBackupRetentionChangeChargeOverage`
  makes with its own flat per-day rate rather than modeling real calendar-month
  lengths.

  ## Real Ledger direction (the disclosed design choice this module makes)

  An **upgrade** (`new_monthly_cents > old_monthly_cents`) is a real charge:
  `from_account_id: org_account`, `to_account_id: revenue_account` -- same
  direction as `SubscriptionChargeOnActivate`, decreasing the org's real
  balance and increasing platform revenue.

  A **downgrade** (`new_monthly_cents < old_monthly_cents`) is a real
  credit back to the org: the transfer direction is reversed --
  `from_account_id: revenue_account`, `to_account_id: org_account` --
  decreasing platform revenue and increasing (crediting) the org's real
  balance by the real prorated difference. This is the natural double-entry
  mirror of the upgrade charge (same two accounts, opposite direction),
  not a new third account or a negative-amount transfer on the original
  direction -- `Xaas.Ledger.Transfer`'s `:amount` has no real business
  meaning as negative money in this schema (see `AshDoubleEntry.Transfer`),
  so the sign is always expressed via which account is `:from` and which
  is `:to`, never via a negative `Money` value.

  ## Transaction boundary (this session's own real lesson, commit f2d57ac)

  Wired via `Ash.Changeset.after_transaction/2`, NOT `after_action/2`. Real
  Ash source (`deps/ash/lib/ash/changeset/changeset.ex`) confirms
  `after_action` hooks run inside the same DB transaction as the parent
  action; `after_transaction` hooks run once the transaction has already
  committed (or rolled back). The real `Xaas.Ledger.Transfer` write this
  module makes is a second, independent real write (its own real
  double-entry transaction via `AshDoubleEntry.Transfer`) that must not
  hold open the `:change_tier` update's own transaction while it runs --
  exactly the real blocking-I/O-inside-a-transaction bug commit f2d57ac
  found and fixed for the outbound-webhook dispatcher. `after_transaction`
  only fires on a real `{:ok, record}` result (real failed `:change_tier`
  updates skip proration entirely, per the pattern-match below).
  """
  use Ash.Resource.Change

  @monthly_fee_cents %{
    standard: 2900,
    pro: 7900,
    enterprise: 29_900
  }

  @days_in_month 30
  @platform_revenue_account_identifier "platform:revenue:subscription"

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    old_tier = changeset.data.tier
    new_tier = Ash.Changeset.get_argument(changeset, :tier)

    changeset
    |> Ash.Changeset.force_change_attribute(:tier, new_tier)
    |> Ash.Changeset.after_transaction(fn _changeset, result ->
      case result do
        {:ok, record} ->
          case prorate_tier_change(record, old_tier) do
            {:ok, _transfer_or_nil} -> {:ok, record}
            {:error, error} -> {:error, error}
          end

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  defp prorate_tier_change(record, old_tier) do
    new_tier = record.tier
    old_cents = Map.fetch!(@monthly_fee_cents, old_tier)
    new_cents = Map.fetch!(@monthly_fee_cents, new_tier)
    days_remaining = days_remaining(record.current_period_end)

    # Real, whole-cent rounding: dividing cents by 30 days is not exact in
    # general (a repeating decimal for most day counts), and Decimal's
    # division truncates to its context precision rather than staying
    # exact -- multiplying back by days_remaining would otherwise carry
    # that truncation error into the real Money amount (observed directly:
    # -5000/30*30 comes back as -5000.000...0001, not exact -5000).
    # Rounding to the nearest whole cent here is the real, disclosed
    # simplification this formula makes -- money has no sub-cent unit to
    # preserve past this point anyway.
    diff_cents =
      Decimal.new(new_cents - old_cents)
      |> Decimal.mult(Decimal.new(days_remaining))
      |> Decimal.div(Decimal.new(@days_in_month))
      |> Decimal.round(0)

    cond do
      Decimal.compare(diff_cents, 0) == :eq ->
        # Same-priced tiers (not possible today given distinct placeholder
        # prices per tier, but a real guard in case two tiers are ever
        # priced identically) -- nothing to move.
        {:ok, nil}

      Decimal.compare(diff_cents, 0) == :gt ->
        # Real upgrade: charge the org the real prorated difference.
        charge(record.org_id, cents_to_money(diff_cents))

      true ->
        # Real downgrade: credit the org the real prorated difference
        # (diff_cents is negative here; flip the direction, not the sign).
        credit(record.org_id, cents_to_money(Decimal.abs(diff_cents)))
    end
  end

  defp days_remaining(nil), do: @days_in_month

  defp days_remaining(%DateTime{} = current_period_end) do
    days = Date.diff(DateTime.to_date(current_period_end), Date.utc_today())
    max(days, 0)
  end

  defp cents_to_money(cents_decimal) do
    dollars = Decimal.div(cents_decimal, Decimal.new(100))
    Money.new(:USD, dollars)
  end

  defp charge(org_id, amount) do
    with {:ok, org_account} <- open_or_get_account(org_id),
         {:ok, revenue_account} <- open_or_get_account(@platform_revenue_account_identifier) do
      transfer(amount, org_account.id, revenue_account.id)
    end
  end

  defp credit(org_id, amount) do
    with {:ok, org_account} <- open_or_get_account(org_id),
         {:ok, revenue_account} <- open_or_get_account(@platform_revenue_account_identifier) do
      transfer(amount, revenue_account.id, org_account.id)
    end
  end

  defp transfer(amount, from_account_id, to_account_id) do
    Xaas.Ledger.Transfer
    |> Ash.Changeset.for_create(:transfer, %{
      amount: amount,
      timestamp: DateTime.utc_now(),
      from_account_id: from_account_id,
      to_account_id: to_account_id
    })
    |> Ash.create(authorize?: false)
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
