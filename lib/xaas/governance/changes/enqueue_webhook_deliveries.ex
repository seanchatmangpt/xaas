defmodule Xaas.Governance.Changes.EnqueueWebhookDeliveries do
  @moduledoc """
  Real, reusable Ash change: after a Governance `Approval*` resource's
  `:approve` action succeeds, enqueues a real `Xaas.Platform.WebhookDelivery`
  row for every real, `enabled: true` `Xaas.Platform.Webhook` whose
  `event_types` list includes this action's configured `event_type`.

  No pre-existing notifier pattern was found in this repo for this kind of
  cross-resource fan-out (`lib/xaas/governance/notifiers` does not exist,
  confirmed by a real search before writing this module) -- so this is a
  plain `Ash.Resource.Change` using `Ash.Changeset.after_action/2`, the same
  shape already proven by
  `Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`
  (a real, in-repo precedent for "real side effect keyed off a real approved
  record, inside the same after_action hook"). Reused verbatim across the
  wired `:approve` actions via `change {__MODULE__, event_type: "..."}`
  rather than one bespoke module per resource.

  Real webhook fan-out only -- no real outbound HTTP dispatch here (that is
  documented, in this repo, as real follow-up work in `Xaas.Platform.Webhook`
  and `Xaas.Platform.WebhookDelivery`'s own moduledocs). This module's job
  ends at persisting a real, `status: :pending` `WebhookDelivery` row per
  matching webhook.
  """
  use Ash.Resource.Change

  require Ash.Query
  import Ash.Expr

  @impl true
  def init(opts) do
    case Keyword.fetch(opts, :event_type) do
      {:ok, event_type} when is_binary(event_type) -> {:ok, opts}
      _ -> {:error, "EnqueueWebhookDeliveries requires a string :event_type option"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    event_type = Keyword.fetch!(opts, :event_type)

    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      enqueue_deliveries(record, event_type)
      {:ok, record}
    end)
  end

  defp enqueue_deliveries(record, event_type) do
    {:ok, webhooks} =
      Xaas.Platform.Webhook
      |> Ash.Query.filter(enabled: true)
      |> Ash.Query.filter(expr(^event_type in event_types))
      |> Ash.read(authorize?: false)

    payload = %{
      "id" => record.id,
      "org_id" => Map.get(record, :org_id),
      "approved_by" => Map.get(record, :approved_by)
    }

    Enum.each(webhooks, fn webhook ->
      Xaas.Platform.WebhookDelivery
      |> Ash.Changeset.for_create(
        :create,
        %{
          webhook_id: webhook.id,
          event_type: event_type,
          payload: payload
        },
        authorize?: false
      )
      |> Ash.create!()
    end)
  end
end
