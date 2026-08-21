defmodule Xaas.Billing.Changes.ApprovalSlaCreditApplyApprove do
  @moduledoc """
  Real, disclosed NEW business logic (this resource previously had zero
  Ledger integration -- approving an SLA credit application moved no real
  money at all). Mirrors `Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`
  / `Xaas.Billing.Changes.SubscriptionChargeOnActivate`'s "be its own
  payment processor" pattern, but crediting instead of charging: on a
  real, first-time `:approve`, a real `Xaas.Ledger.Transfer` moves the
  request's real `credit_amount_cents` from a dedicated
  `platform:revenue:sla-credits` platform account to the org's real
  `Xaas.Ledger.Account`.

  ## Why a dedicated `platform:revenue:sla-credits` account, not
  `platform:revenue:backup-retention-overage` or
  `platform:revenue:subscription`

  Both of those accounts accumulate real platform *revenue* (money
  flowing FROM an org TO the platform). An SLA credit is the opposite: a
  real cost/refund the platform owes the org for an SLA breach, money
  flowing FROM the platform TO the org. Crediting an org from a revenue
  account would net against real revenue figures those accounts are
  meant to report cleanly; a distinct liability-shaped account keeps SLA
  credit outflows separately attributable instead of silently eroding
  revenue-account balances.

  ## Real per-session precedent this uses `after_transaction/2`, not
  `after_action/2`

  Per this session's own `f2d57ac` transaction-boundary lesson
  (documented in `Xaas.Governance.Changes.EnqueueWebhookDeliveries`'s
  moduledoc): `after_action/2` callbacks run *inside* the parent
  `:approve` action's transaction (real Ash source,
  `deps/ash/lib/ash/changeset/changeset.ex`'s `transaction_hooks/2`),
  while `after_transaction/2` callbacks only run once that transaction
  has already committed or rolled back. Real Ledger writes (account
  lookup/open + transfer create) are real DB round-trips of their own;
  running them via `after_transaction/2` avoids nesting them inside (and
  holding open) the parent transaction, consistent with the
  adversarial-review-verified pattern this codebase already settled on.

  ## Idempotency

  Same "check the changeset's pre-change state" discipline as
  `SubscriptionChargeOnActivate`'s `newly_activated?/2`: only credits
  when `changeset.data.approved_by` (the real pre-update value) was
  nil/blank and the post-update record now has a real `approved_by` --
  i.e. only on the request's real first successful `:approve`. A second
  `:approve` call against an already-approved record does not credit
  again.
  """
  use Ash.Resource.Change

  @platform_sla_credits_account_identifier "platform:revenue:sla-credits"

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn changeset, result ->
      case result do
        {:ok, record} ->
          if newly_approved?(changeset, record) do
            case credit_sla(record) do
              {:ok, _transfer} -> {:ok, record}
              {:error, error} -> {:error, error}
            end
          else
            {:ok, record}
          end

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  defp newly_approved?(changeset, record) do
    prev = changeset.data.approved_by
    (is_nil(prev) or prev == "") and is_binary(record.approved_by) and record.approved_by != ""
  end

  defp credit_sla(record) do
    dollars = Decimal.div(Decimal.new(record.credit_amount_cents), Decimal.new(100))
    amount = Money.new(:USD, dollars)

    with {:ok, sla_credits_account} <- open_or_get_account(@platform_sla_credits_account_identifier),
         {:ok, org_account} <- open_or_get_account(record.org_id) do
      Xaas.Ledger.Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: amount,
        timestamp: DateTime.utc_now(),
        from_account_id: sla_credits_account.id,
        to_account_id: org_account.id
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
