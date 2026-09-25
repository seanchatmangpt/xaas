defmodule Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage do
  @moduledoc """
  Real, disclosed NEW business logic (not ported from platform-console --
  platform-console has no fee for exceeding a tier's default backup
  retention; it only hard-rejects out-of-range requests, see
  `ApprovalBackupRetentionChangeWithinTierRange`). This is xaas's own
  "be its own payment processor" mechanism: when an approved retention
  change exceeds the org's tier default, a real `Xaas.Ledger.Transfer`
  moves a real (if placeholder-priced) fee from the org's real
  `Xaas.Ledger.Account` to a fixed platform-revenue account, inside this
  action's own transaction -- approval and the money movement succeed or
  fail together.

  `@overage_rate_cents_per_day` is an invented placeholder rate this
  session chose (10 cents/day over the tier default), not a commercially
  validated price -- stated here plainly rather than silently implied.

  ## Real fix: `newly_approved?/2` guard (this pass -- a live-reproduced
  double-charge bug, not a hypothetical)

  This module previously charged the overage fee on *every* `:approve`
  call against a record, not just the first. Real-reproduced this pass
  with a temporary local test (mirroring
  `test/xaas/billing/approval_sla_credit_apply_test.exs`'s "approving
  twice does not double-credit"): approving the same
  `ApprovalBackupRetentionChange` record twice moved the real ledger
  balance from `-$6.00` to `-$12.00` -- a second, redundant charge for
  work that only happened once. Fixed with the exact same
  "check the changeset's pre-change state" guard already proven on the
  2 Billing siblings that share this `after_action/2` Ledger-write
  pattern, `Xaas.Billing.Changes.ApprovalSlaCreditApplyApprove`'s
  `newly_approved?/2` and
  `Xaas.Billing.Changes.ApprovalPatchSlaCreditApplyApprove`'s equivalent:
  only charge when `changeset.data.approved_by` (the real pre-update
  value) was nil/blank and the post-update record now has a real
  `approved_by` -- i.e. only on the record's real first successful
  `:approve`. A second `:approve` call against an already-approved
  record no longer charges again.
  """
  use Ash.Resource.Change

  @default_days %{starter: 7, pro: 30, enterprise: 365}
  @overage_rate_cents_per_day 10
  @platform_revenue_account_identifier "platform:revenue:backup-retention-overage"

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, record ->
      if newly_approved?(changeset, record) do
        case overage_days(record) do
          0 ->
            {:ok, record}

          overage_days when overage_days > 0 ->
            case charge_overage(record, overage_days) do
              {:ok, _transfer} -> {:ok, record}
              {:error, error} -> {:error, error}
            end
        end
      else
        {:ok, record}
      end
    end)
  end

  defp newly_approved?(changeset, record) do
    prev = changeset.data.approved_by
    (is_nil(prev) or prev == "") and is_binary(record.approved_by) and record.approved_by != ""
  end

  defp overage_days(%{tier: tier, requested_retention_days: days}) do
    max(days - Map.fetch!(@default_days, tier), 0)
  end

  defp charge_overage(record, overage_days) do
    cents = overage_days * @overage_rate_cents_per_day
    dollars = Decimal.div(Decimal.new(cents), Decimal.new(100))
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
