defmodule Xaas.Billing.Changes.ApprovalTierDowngradeApprove do
  @moduledoc """
  Real logic replacing a prior byte-identical no-op stub (`def change(changeset,
  _opts, _context) do changeset end`, real, disclosed dead code found by the
  eleventh-pass ERRC grid sweep -- it was never even wired into the
  `:approve` action, so approving a tier downgrade had zero real effect).

  On a real, successful `:approve`, this drives `Xaas.Billing.Subscription`'s
  real, already-atomic `:change_tier` action
  (`lib/xaas/billing/subscription.ex:226-236`) with this record's own
  `requested_tier`, via `Ash.Changeset.after_action/2` -- NOT
  `after_transaction/2`. `after_action/2` runs *inside* the parent `:approve`
  transaction (real Ash source, `deps/ash/lib/ash/changeset/changeset.ex`'s
  `transaction_hooks/2`), matching the now-established atomic pattern this
  codebase settled on for every other money/state-moving `:approve` side
  effect (`Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`,
  `Xaas.Billing.Changes.SubscriptionProrateTierChange` itself, both real,
  tested, and cited by every fixed sibling as the pattern to match). A real
  failure inside `Subscription.change_tier` (including its own real,
  already-atomic prorated `Xaas.Ledger.Transfer` write) rolls this
  approval's `approved_by` back too, inside the same outer transaction --
  never approved-but-not-downgraded.

  `Subscription.change_tier`'s own transaction nests inside this one (the
  same real nesting already proven safe throughout this codebase: every
  `*ChargeOverage`/`SubscriptionProrateTierChange` module already calls
  `Ash.create/2` on a second resource -- `Xaas.Ledger.Transfer` -- from
  inside its own `after_action/2` hook, and that create runs its own
  AshPostgres-wrapped transaction the same way).
  """
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      case apply_downgrade(record) do
        {:ok, _subscription} -> {:ok, record}
        {:error, error} -> {:error, error}
      end
    end)
  end

  defp apply_downgrade(record) do
    with {:ok, subscription} <-
           Ash.get(Xaas.Billing.Subscription, record.subscription_id, authorize?: false) do
      subscription
      |> Ash.Changeset.for_update(:change_tier, %{tier: record.requested_tier})
      |> Ash.update(authorize?: false)
    end
  end
end
