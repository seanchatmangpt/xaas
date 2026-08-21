defmodule Xaas.Billing.Changes.ApprovalPatchSlaCreditApplyApprove do
  @moduledoc """
  Real, disclosed NEW business logic (this resource previously had zero
  Ledger integration -- approving a patch SLA credit application moved no real
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

  ## Real fix: `after_action/2`, not `after_transaction/2` (corrected --
  this module previously got this backwards)

  This module originally used `after_transaction/2`, reasoning (wrongly)
  from this session's own `f2d57ac` transaction-boundary lesson
  (`Xaas.Governance.Changes.EnqueueWebhookDeliveries`'s moduledoc): that
  lesson is about not holding a DB transaction open across *blocking I/O
  to an external system* (an outbound HTTP webhook dispatch). A
  `Xaas.Ledger.Transfer`/`Xaas.Ledger.Account` write is not that -- it is
  a second real write to the *same* Postgres database, and
  `after_transaction/2` only runs once the parent `:approve` transaction
  has already committed. That meant a real Ledger failure here (including
  the real, concretely-triggerable unique-constraint race on
  `Xaas.Ledger.Account`'s `identity :unique_identifier, [:identifier]`,
  hit when two concurrent `:approve` calls both race to open the same
  not-yet-existing org account) left the record **permanently
  "approved but never credited"** with silently-failed money movement and
  no automatic remediation path -- `approved_by` was already committed
  and could not be rolled back after the fact.

  `Ash.Changeset.after_action/2` runs *inside* the parent `:approve`
  transaction (real Ash source, `deps/ash/lib/ash/changeset/changeset.ex`'s
  `transaction_hooks/2`) and a `{:error, _}` return from it rolls the whole
  transaction -- including the `approved_by` write -- back. This is the
  exact same real, already-proven-working pattern
  `Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`
  uses for its own Ledger charge; this module now matches it instead of
  being one of its two silent exceptions.

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
    Ash.Changeset.after_action(changeset, fn changeset, record ->
      if newly_approved?(changeset, record) do
        case credit_sla(record) do
          {:ok, _transfer} -> {:ok, record}
          {:error, error} -> {:error, error}
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
