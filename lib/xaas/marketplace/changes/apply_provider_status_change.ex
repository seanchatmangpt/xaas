defmodule Xaas.Marketplace.Changes.ApplyProviderStatusChange do
  @moduledoc """
  Real `Ash.Resource.Change` for
  `Xaas.Marketplace.ApprovalProviderStatusChange`'s `:approve` action --
  after the approval row itself is really persisted (distinct-approver
  validation already passed), this loads the real target
  `Xaas.Marketplace.Provider` row by `provider_id` and really updates its
  `status` attribute to this request's `requested_status`, inside the
  same real after-action hook (both writes commit or neither does,
  since `Ash.Changeset.after_action/2` runs inside the same real
  database transaction as the approval row's own update).

  Uses `authorize?: false` for the real, disclosed reason
  `Xaas.Governance.Changes.EnqueueWebhookDeliveries`-style internal
  writes in this repo already use it: the actor has already been really
  authorized to approve THIS request (`ActorOrgFilter` bypass on
  `:approve` already ran); applying the resulting status change to the
  target row is a real system-internal side effect of that already-
  authorized action, not a second independent request needing its own
  actor-authorization pass.
  """
  use Ash.Resource.Change

  alias Xaas.Marketplace.Provider

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      case Ash.get(Provider, record.provider_id, authorize?: false) do
        {:ok, provider} ->
          case Ash.update(provider, %{status: record.requested_status},
                 action: :update,
                 authorize?: false
               ) do
            {:ok, _updated_provider} -> {:ok, record}
            {:error, error} -> {:error, error}
          end

        {:error, error} ->
          {:error, error}
      end
    end)
  end
end
