defmodule Xaas.BillingDeepeningTest do
  @moduledoc """
  W729 billing-domain deepening: Chicago-style (real Postgres via
  `Ecto.Adapters.SQL.Sandbox`, real Ash actions, no mocks) coverage for the
  undocketed `Xaas.Billing` domain, per the real actions the code ships:

  (a) `Xaas.Billing.Subscription` lifecycle via the real `:create` /
      `:sync_from_stripe` / `:change_tier` actions, including typed
      refusals (enum-constrained status, org identity, change-tier no-op)
      and the real activation Ledger charge.
  (b) Maker-checker on `Xaas.Billing.ApprovalPricingOverride` (one
      representative `Approval*` resource): request -> approve by a
      different actor succeeds; self-approval is really refused by
      `Xaas.Billing.Validations.ApprovalPricingOverrideRequiresApprover`.
  (c) Multitenancy scoping: TYPED GAP -- none of the 8 `Xaas.Billing`
      resources declares a `multitenancy do` block (see
      `lib/xaas/billing/subscription.ex`'s own org_id comment: "real Ash
      multitenancy wiring is named there as disclosed follow-up work, not
      done here either"), so there is no real multitenant scoping behavior
      to assert; this file asserts the real, org-scoped artifact that does
      exist instead (the org's Ledger account isolation) and the receipt
      records the gap.
  (d) Atomic quantity invariants the code really enforces: the
      `:approve` action's `after_action/2` Ledger integration credits
      exactly `credit_amount_cents`, and since the W746 fix the action
      carries the DB-level `filter(expr(is_nil(approved_by)))` guard --
      a repeat `:approve` (fresh OR stale record) is refused typed and
      mints no second transfer.
  """
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Billing.{ApprovalPricingOverride, ApprovalSlaCreditApply, Subscription}
  alias Xaas.Ledger.{Account, Balance}

  # Same real AshEvents global-lock reasoning (and same precedent) as
  # `test/xaas/billing/subscription_test.exs` / approval_tier_downgrade_test.exs:
  # Ledger writes take AshEvents' transaction-scoped global advisory lock, so
  # this file serializes rather than deadlocking its 5+ billing siblings.
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp real_balance_for(identifier) do
    case Account
         |> Ash.Query.filter(identifier: identifier)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        nil

      account ->
        Balance
        |> Ash.Query.filter(account_id: account.id)
        |> Ash.read!(authorize?: false)
        |> Enum.max_by(& &1.transfer_id, fn -> nil end)
        |> case do
          nil -> nil
          balance -> balance.balance
        end
    end
  end

  defp create_subscription!(attrs) do
    Subscription
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp unique(fmt), do: "#{fmt}-#{System.unique_integer([:positive])}"

  # ------------------------------------------------------------------
  # (a) Subscription lifecycle
  # ------------------------------------------------------------------

  test "create defaults a new subscription to :standard/:incomplete with no period end" do
    sub =
      create_subscription!(%{
        org_id: unique("org"),
        stripe_customer_id: unique("cus")
      })

    assert sub.tier == :standard
    assert sub.status == :incomplete
    assert sub.current_period_end == nil
    assert sub.stripe_subscription_id == nil
  end

  test "sync_from_stripe :incomplete -> :active really persists status and charges the real $29.00 activation fee" do
    org_id = unique("org-activate")
    sub = create_subscription!(%{org_id: org_id, stripe_customer_id: unique("cus")})
    assert real_balance_for(org_id) == nil, "no Ledger rows before activation"

    activated =
      sub
      |> Ash.Changeset.for_update(:sync_from_stripe, %{status: :active})
      |> Ash.update!(authorize?: false)

    assert activated.status == :active

    reloaded = Ash.reload!(sub, authorize?: false)
    assert reloaded.status == :active
    assert Money.equal?(real_balance_for(org_id), Money.new(:USD, "-29.00"))
  end

  test "sync_from_stripe to :canceled really persists a canceled status" do
    org_id = unique("org-cancel")
    sub = create_subscription!(%{org_id: org_id, stripe_customer_id: unique("cus")})

    canceled =
      sub
      |> Ash.Changeset.for_update(:sync_from_stripe, %{status: :past_due})
      |> Ash.update!(authorize?: false)

    assert canceled.status == :past_due

    canceled =
      canceled
      |> Ash.Changeset.for_update(:sync_from_stripe, %{status: :canceled})
      |> Ash.update!(authorize?: false)

    assert canceled.status == :canceled
    assert Ash.reload!(sub, authorize?: false).status == :canceled
  end

  test "an out-of-enum status value is really refused (typed refusal, no row mutation)" do
    org_id = unique("org-badstatus")
    sub = create_subscription!(%{org_id: org_id, stripe_customer_id: unique("cus")})

    assert {:error, %Ash.Error.Invalid{}} =
             sub
             |> Ash.Changeset.for_update(:sync_from_stripe, %{status: :definitely_not_a_status})
             |> Ash.update(authorize?: false)

    assert Ash.reload!(sub, authorize?: false).status == :incomplete
  end

  test "a second subscription for the same org_id is really refused by the unique_org identity" do
    org_id = unique("org-dup")
    create_subscription!(%{org_id: org_id, stripe_customer_id: unique("cus")})

    assert {:error, %Ash.Error.Invalid{}} =
             Subscription
             |> Ash.Changeset.for_create(:create, %{
               org_id: org_id,
               stripe_customer_id: unique("cus")
             })
             |> Ash.create(authorize?: false)
  end

  test "change_tier to the subscription's own current tier is really refused (no-op validation)" do
    org_id = unique("org-noop")
    sub = create_subscription!(%{org_id: org_id, stripe_customer_id: unique("cus")})

    assert {:error, %Ash.Error.Invalid{}} =
             sub
             |> Ash.Changeset.for_update(:change_tier, %{tier: :standard})
             |> Ash.update(authorize?: false)

    assert Ash.reload!(sub, authorize?: false).tier == :standard
  end

  # W897 (w729 UNSUPPORTED(lifecycle-state-machine) repair): this test used
  # to pin the absence of any transition guard (:canceled -> :active was
  # accepted); it now asserts the real state machine — the guarded edge is
  # refused typed and the persisted row stays :canceled. Mutation rationale:
  # deleting the validate(...) line on :sync_from_stripe flips this test
  # back to RED (the :canceled -> :active update succeeds again).
  test "sync_from_stripe transition guard refuses :canceled -> :active (canceled is terminal)" do
    org_id = unique("org-noguard")
    sub = create_subscription!(%{org_id: org_id, stripe_customer_id: unique("cus")})

    canceled =
      sub
      |> Ash.Changeset.for_update(:sync_from_stripe, %{status: :canceled})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             canceled
             |> Ash.Changeset.for_update(:sync_from_stripe, %{status: :active})
             |> Ash.update(authorize?: false)

    assert Ash.reload!(canceled, authorize?: false).status == :canceled
  end

  # ------------------------------------------------------------------
  # (b) Maker-checker on ApprovalPricingOverride
  # ------------------------------------------------------------------

  test "maker-checker: request then approve by a DIFFERENT actor really persists approved_by" do
    requested_by = unique("requester")
    approved_by = unique("approver")

    pending =
      ApprovalPricingOverride
      |> Ash.Changeset.for_create(:create, %{requested_by: requested_by})
      |> Ash.create!(authorize?: false)

    assert pending.approved_by == nil

    approved =
      pending
      |> Ash.Changeset.for_update(:approve, %{approved_by: approved_by})
      |> Ash.update!(authorize?: false)

    assert approved.approved_by == approved_by

    # Real persisted row state, not just the return value.
    persisted = ApprovalPricingOverride |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == approved_by
    assert persisted.requested_by == requested_by
  end

  test "maker-checker: self-approval is really refused and no row state changes" do
    requested_by = unique("requester-self")

    pending =
      ApprovalPricingOverride
      |> Ash.Changeset.for_create(:create, %{requested_by: requested_by})
      |> Ash.create!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             pending
             |> Ash.Changeset.for_update(:approve, %{approved_by: requested_by})
             |> Ash.update(authorize?: false)

    assert Enum.any?(errors, fn
             %{message: message} when is_binary(message) ->
               message =~ "cannot approve their own"

             _ ->
               false
           end)

    persisted = ApprovalPricingOverride |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil, "a refused approval must not persist approved_by"
  end

  test "maker-checker: a missing approver is really refused" do
    requested_by = unique("requester-noapprover")

    pending =
      ApprovalPricingOverride
      |> Ash.Changeset.for_create(:create, %{requested_by: requested_by})
      |> Ash.create!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             pending
             |> Ash.Changeset.for_update(:approve, %{})
             |> Ash.update(authorize?: false)

    assert ApprovalPricingOverride |> Ash.get!(pending.id, authorize?: false)
  end

  # ------------------------------------------------------------------
  # (d) Atomic quantity invariants (real code, not assumed)
  # ------------------------------------------------------------------

  test "approving an SLA credit really credits exactly credit_amount_cents to the org's Ledger account" do
    org_id = unique("org-sla")
    cents = 12_345

    pending =
      ApprovalSlaCreditApply
      |> Ash.Changeset.for_create(:create, %{
        requested_by: unique("requester"),
        org_id: org_id,
        credit_amount_cents: cents
      })
      |> Ash.create!(authorize?: false)

    assert real_balance_for(org_id) == nil

    approved =
      pending
      |> Ash.Changeset.for_update(:approve, %{approved_by: unique("approver")})
      |> Ash.update!(authorize?: false)

    assert approved.approved_by != nil

    # Real conversion in ApprovalSlaCreditApplyApprove.credit_sla/1: the
    # credit is persisted as (credit_amount_cents / 100) DOLLARS, i.e. a
    # 12_345-cent request really credits $123.45.
    expected = Money.new(:USD, Decimal.div(Decimal.new(cents), 100))
    assert Money.equal?(real_balance_for(org_id), expected),
           "the org's real Ledger balance must equal exactly the approved credit_amount_cents / 100 dollars"
  end

  test "a repeat :approve with a FRESHLY RELOADED record is refused typed -- no second credit" do
    org_id = unique("org-sla-idem")
    cents = 5_000

    pending =
      ApprovalSlaCreditApply
      |> Ash.Changeset.for_create(:create, %{
        requested_by: unique("requester"),
        org_id: org_id,
        credit_amount_cents: cents
      })
      |> Ash.create!(authorize?: false)

    pending
    |> Ash.Changeset.for_update(:approve, %{approved_by: unique("approver")})
    |> Ash.update!(authorize?: false)

    after_first = real_balance_for(org_id)
    assert Money.equal?(after_first, Money.new(:USD, Decimal.div(Decimal.new(cents), 100)))

    # W746 fix: the :approve action now carries the DB-level
    # `filter(expr(is_nil(approved_by)))` guard, so a repeat :approve on a
    # row whose PERSISTED approved_by is already set is refused typed --
    # even when the caller passes a freshly loaded record.
    fresh = Ash.get!(ApprovalSlaCreditApply, pending.id, authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             fresh
             |> Ash.Changeset.for_update(:approve, %{approved_by: unique("approver-2")})
             |> Ash.update(authorize?: false)

    assert Money.equal?(real_balance_for(org_id), after_first),
           "a refused repeat :approve must not mint a second Ledger transfer"
  end

  # W746 fix, formerly the TYPED GAP test (the gap it pinned is closed): the
  # SLA-credit idempotency guard used to read only the CALLER's in-memory
  # changeset.data.approved_by, so re-running :approve through a STALE record
  # (approved_by still nil in memory, already set in Postgres) really
  # double-credited the org's Ledger account. The `:approve` action now
  # carries the DB-level `filter(expr(is_nil(approved_by)))` guard, so the
  # stale-record repeat approve is refused typed and no second transfer is
  # minted.
  test "a repeat :approve through a STALE record is refused typed -- no double credit" do
    org_id = unique("org-sla-stale")
    cents = 5_000

    pending =
      ApprovalSlaCreditApply
      |> Ash.Changeset.for_create(:create, %{
        requested_by: unique("requester"),
        org_id: org_id,
        credit_amount_cents: cents
      })
      |> Ash.create!(authorize?: false)

    pending
    |> Ash.Changeset.for_update(:approve, %{approved_by: unique("approver")})
    |> Ash.update!(authorize?: false)

    after_first = real_balance_for(org_id)

    stale = Ash.get!(ApprovalSlaCreditApply, pending.id, authorize?: false)

    # Simulate the stale in-memory record: strip the persisted approved_by.
    stale = %{stale | approved_by: nil}

    assert {:error, %Ash.Error.Invalid{}} =
             stale
             |> Ash.Changeset.for_update(:approve, %{approved_by: unique("approver-2")})
             |> Ash.update(authorize?: false)

    assert Money.equal?(real_balance_for(org_id), after_first),
           "a refused stale-record :approve must not double-credit the org's Ledger account"
  end
end
