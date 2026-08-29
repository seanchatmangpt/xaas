defmodule Xaas.Marketplace.Changes.ApplyProviderStatusChange do
  @moduledoc """
  Maker-checker bridge from an approved status-change request into the canonical
  Reactor actuation path.

  The approval action remains an Ash transaction hook, but it no longer mutates
  `Provider` directly. Instead it manufactures delegated authority evidence and
  invokes `Xaas.Actuation.run/4`. That call admits the provider's public-ontology
  projection, prepares durable intent/receipt rows, runs the consequential Ash
  action through Ash.Reactor, and seals the receipt before the transaction can
  commit.
  """

  use Ash.Resource.Change

  alias Xaas.Marketplace.Provider

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      authority = %{
        kind: "maker_checker_approval",
        approval_resource: inspect(record.__struct__),
        approval_id: to_string(record.id),
        approved_by: stringify(record.approved_by),
        org_id: stringify(record.org_id),
        requested_status: to_string(record.requested_status)
      }

      current = Ash.get!(Provider, record.provider_id, authorize?: false)

      with {:ok, action} <- target_action(current.status, record.requested_status),
           {:ok, _receipt_envelope} <-
             Xaas.Actuation.run(
               Provider,
               action,
               %{},
               subject_id: record.provider_id,
               idempotency_key: "approval-provider-status-change:#{record.id}",
               authorize?: false,
               authority: authority
             ) do
        {:ok, record}
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  # Provider's :status lifecycle is one AshStateMachine action per real target state
  # (see Xaas.Marketplace.Provider's state_machine block); a real, live current status
  # read is required to pick the right one, since `:active` is reachable from both
  # `:pending` (via `:activate`) and `:suspended` (via `:reactivate`), and
  # ApprovalProviderStatusChange itself carries no "previous status" field. An
  # unmapped (current, requested) pair refuses explicitly here rather than crashing or
  # guessing -- AshStateMachine's own transition_state/1 change is a second,
  # redundant safety net underneath this for any pair this mapping did admit.
  defp target_action(:pending, :active), do: {:ok, :activate}
  defp target_action(:suspended, :active), do: {:ok, :reactivate}
  defp target_action(:active, :suspended), do: {:ok, :suspend}

  defp target_action(current, requested),
    do: {:error, {:no_such_provider_status_transition, current, requested}}

  defp stringify(nil), do: nil
  defp stringify(value) when is_binary(value), do: value
  defp stringify(value), do: to_string(value)
end
