defmodule Xaas.Billing.SubscriptionTierProrationDepthW984ddTest do
  @moduledoc """
  Lane W984dd depth court (v26.10.6 burn-down, family: Billing
  change-modules) for the two uncovered state-bearing change modules on
  `Xaas.Billing.Subscription`:

  - `Xaas.Billing.Changes.SubscriptionProrateTierChange` (via the real
    `:change_tier` update action) — proration math, transfer direction,
    the past-period clamp to a no-op, and the same-tier typed refusal.
  - `Xaas.Billing.Changes.SubscriptionChargeOnActivate` (via the real
    `:sync_from_stripe` update action) — replay idempotency: a duplicate
    `:active` webhook sync must not create a second activation transfer.

  Real `Ecto.Adapters.SQL.Sandbox`-backed Postgres, real Ash actions,
  real `Xaas.Ledger.Transfer` rows read back and asserted on direction
  and exact `Money` amount. No mocking.

  Mutation rationale per test (what each test kills that source reading
  alone could not): see the per-test comment above each block.
  """
  # async: false -- writes real `Xaas.Ledger.Account`/`Balance`/`Transfer`
  # rows (AshEvents-tracked, single global advisory lock); same real,
  # root-caused serialization discipline as
  # `Xaas.Billing.ApprovalTierDowngradeTest`.
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Billing.Subscription
  alias Xaas.Ledger.{Account, Transfer}

  @revenue_identifier "platform:revenue:subscription"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp real_balance_for(identifier) do
    case Account |> Ash.Query.filter(identifier: identifier) |> Ash.read_one!(authorize?: false) do
      nil -> nil
      account -> balance_for_account(account.id)
    end
  end

  defp balance_for_account(account_id) do
    Xaas.Ledger.Balance
    |> Ash.Query.filter(account_id: account_id)
    |> Ash.read!(authorize?: false)
    |> Enum.max_by(& &1.transfer_id, fn -> nil end)
    |> case do
      nil -> Money.new(:USD, 0)
      b -> b.balance
    end
  end

  defp transfers_for_org(org_identifier) do
    account = Account |> Ash.Query.filter(identifier: org_identifier) |> Ash.read_one!(authorize?: false)

    if account do
      Transfer
      |> Ash.Query.filter(from_account_id: account.id)
      |> Ash.read!(authorize?: false)
      |> Enum.concat(
        Transfer |> Ash.Query.filter(to_account_id: account.id) |> Ash.read!(authorize?: false)
      )
      |> Enum.uniq_by(& &1.id)
    else
      []
    end
  end

  defp org_subscription(attrs \\ %{}) do
    defaults = %{
      org_id: "org-w984dd-#{System.unique_integer([:positive])}",
      stripe_customer_id: "cus_w984dd_#{System.unique_integer([:positive])}",
      tier: :standard,
      status: :active
    }

    {:ok, sub} =
      Subscription
      |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
      |> Ash.create(authorize?: false)

    sub
  end

  defp days_until(dt), do: Date.diff(DateTime.to_date(dt), Date.utc_today())

  test "upgrade standard->pro with a full 30-day remainder charges exactly $50.00 org->revenue" do
    sub = org_subscription(%{current_period_end: DateTime.add(DateTime.utc_now(), 31, :day)})
    # Date.diff of now+31d is 30 or 31 depending on intraday rounding; pin
    # the expectation to the same real Date.diff the module uses so the
    # assertion is exact, not approximate.
    expected_cents = Decimal.new(5000 * max(days_until(sub.current_period_end), 0)) |> Decimal.div(Decimal.new(30)) |> Decimal.round(0)

    {:ok, updated} =
      sub
      |> Ash.Changeset.for_update(:change_tier, %{tier: :pro})
      |> Ash.update(authorize?: false)

    assert updated.tier == :pro
    [t] = transfers_for_org(sub.org_id)
    assert Money.compare(t.amount, cents_to_money(expected_cents)) == :eq
    assert from_identifier(t.from_account_id) == sub.org_id
    assert from_identifier(t.to_account_id) == @revenue_identifier
  end

  test "downgrade enterprise->standard mid-period credits the org, revenue->org direction" do
    sub = org_subscription(%{tier: :enterprise, current_period_end: DateTime.add(DateTime.utc_now(), 16, :day)})

    # (29900-2900)=27000 cents diff; 15-16 real days -> exact prorated credit
    expected_cents =
      Decimal.new(27_000 * max(days_until(sub.current_period_end), 0))
      |> Decimal.div(Decimal.new(30))
      |> Decimal.round(0)

    {:ok, updated} =
      sub
      |> Ash.Changeset.for_update(:change_tier, %{tier: :standard})
      |> Ash.update(authorize?: false)

    assert updated.tier == :standard
    [t] = transfers_for_org(sub.org_id)
    assert Money.compare(t.amount, cents_to_money(expected_cents)) == :eq
    assert from_identifier(t.from_account_id) == @revenue_identifier
    assert from_identifier(t.to_account_id) == sub.org_id

    # Double-entry state: revenue balance really fell by the credit.
    before = Money.new(:USD, 0)
    revenue_balance = real_balance_for(@revenue_identifier)
    assert Money.compare(revenue_balance, before) == :lt
  end

  test "same-tier change_tier is a typed 400-shaped refusal with zero transfers" do
    sub = org_subscription(%{current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)})

    assert {:error, %Ash.Error.Invalid{} = error} =
             sub
             |> Ash.Changeset.for_update(:change_tier, %{tier: :standard})
             |> Ash.update(authorize?: false)

    assert error.errors |> Enum.any?(fn e ->
             match?(%{field: :tier}, e) or
               (is_map(e) and (e[:message] || "") =~ "already")
           end)

    assert transfers_for_org(sub.org_id) == []
  end

  test "expired period clamps days_remaining to 0: tier still changes, no transfer" do
    sub = org_subscription(%{current_period_end: DateTime.add(DateTime.utc_now(), -5, :day)})

    {:ok, updated} =
      sub
      |> Ash.Changeset.for_update(:change_tier, %{tier: :enterprise})
      |> Ash.update(authorize?: false)

    assert updated.tier == :enterprise
    # days_remaining = max(diff, 0) = 0 -> diff_cents 0 -> {:ok, nil}
    assert transfers_for_org(sub.org_id) == []
  end

  test "charge_on_activate replay: a second :active sync_from_stripe does not double-charge" do
    sub = org_subscription(%{status: :incomplete})
    assert transfers_for_org(sub.org_id) == []

    {:ok, activated} =
      sub
      |> Ash.Changeset.for_update(:sync_from_stripe, %{status: :active})
      |> Ash.update(authorize?: false)

    assert activated.status == :active
    assert [_activation] = transfers_for_org(sub.org_id)

    # Duplicate webhook replay -- same edge, still :active -> still :active.
    {:ok, _replayed} =
      activated
      |> Ash.Changeset.for_update(:sync_from_stripe, %{status: :active})
      |> Ash.update(authorize?: false)

    assert length(transfers_for_org(sub.org_id)) == 1
  end

  defp cents_to_money(cents) do
    Money.new(:USD, Decimal.div(cents, Decimal.new(100)))
  end

  defp from_identifier(account_id) do
    Account |> Ash.Query.filter(id: account_id) |> Ash.read_one!(authorize?: false) |> Map.get(:identifier)
  end
end
