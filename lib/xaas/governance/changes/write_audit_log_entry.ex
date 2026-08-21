defmodule Xaas.Governance.Changes.WriteAuditLogEntry do
  @moduledoc """
  Real, reusable Ash change: after a Governance `Approval*` resource's
  `:approve` action succeeds, writes one real
  `Xaas.Operations.AuditLogEntry` row recording who did what, when.

  Mirrors `Xaas.Governance.Changes.EnqueueWebhookDeliveries`'s real
  `after_transaction/2` pattern (not `after_action/2`) for the same
  reason documented there: `after_action/2` runs inside the parent
  `:approve` transaction, so any real work done there holds a real
  Postgres connection/transaction open. This change's own work (a
  single `Ash.create!/2` on `AuditLogEntry`) is comparatively cheap, but
  using `after_transaction/2` keeps this change consistent with the
  established, adversarial-review-verified pattern in this file's
  sibling, and means it only ever fires once the parent `:approve` has
  actually, durably committed -- an `AuditLogEntry` row can never exist
  for an approval that itself rolled back.

  Reused verbatim across the wired `:approve` actions via
  `change {__MODULE__, action: "...", resource_type: "..."}`.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    with {:ok, action} when is_binary(action) <- Keyword.fetch(opts, :action),
         {:ok, resource_type} when is_binary(resource_type) <-
           Keyword.fetch(opts, :resource_type) do
      {:ok, opts}
    else
      _ ->
        {:error,
         "WriteAuditLogEntry requires string :action and :resource_type options"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    action = Keyword.fetch!(opts, :action)
    resource_type = Keyword.fetch!(opts, :resource_type)

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      case result do
        {:ok, record} ->
          write_entry(record, action, resource_type)
          {:ok, record}

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  defp write_entry(record, action, resource_type) do
    actor_id = Map.get(record, :approved_by)

    Xaas.Operations.AuditLogEntry
    |> Ash.Changeset.for_create(
      :create,
      %{
        actor_id: actor_id,
        actor_description: actor_id,
        action: action,
        resource_type: resource_type,
        resource_id: to_string(record.id),
        org_id: Map.get(record, :org_id),
        occurred_at: DateTime.utc_now(),
        metadata: %{"requested_by" => Map.get(record, :requested_by)}
      },
      authorize?: false
    )
    |> Ash.create!()
  end
end
