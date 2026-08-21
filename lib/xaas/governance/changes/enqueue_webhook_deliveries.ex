defmodule Xaas.Governance.Changes.EnqueueWebhookDeliveries do
  @moduledoc """
  Real, reusable Ash change: after a Governance `Approval*` resource's
  `:approve` action succeeds, enqueues a real `Xaas.Platform.WebhookDelivery`
  row for every real, `enabled: true` `Xaas.Platform.Webhook` whose
  `event_types` list includes this action's configured `event_type`, and
  dispatches a real outbound HTTP POST for each one via the `:deliver`
  action.

  No pre-existing notifier pattern was found in this repo for this kind of
  cross-resource fan-out (`lib/xaas/governance/notifiers` does not exist,
  confirmed by a real search before writing this module) -- so this is a
  plain `Ash.Resource.Change`. Reused verbatim across the wired `:approve`
  actions via `change {__MODULE__, event_type: "..."}` rather than one
  bespoke module per resource.

  ## Real bug fixed here: after_action/2 vs after_transaction/2

  This originally used `Ash.Changeset.after_action/2`
  (following `Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`'s
  precedent), which runs its callback *inside* the same database
  transaction/connection-checkout as the parent `:approve` action -- see
  `deps/ash/lib/ash/changeset/changeset.ex`'s `transaction_hooks/2`: the
  `after_action` phase runs as part of `func.(...)`, the function executed
  *inside* `Ash.DataLayer.transaction/...`, whereas `after_transaction/2`
  callbacks are only invoked afterwards, via `run_after_transactions/2`,
  once `func.(...)` (the transaction itself) has already returned
  `{:ok, result, ...}` or `{:error, ...}`. Concretely: `run_after_transactions`
  is called on the *result* of the transaction, not from within it.

  Because `enqueue_deliveries/2` performs a real, blocking outbound HTTP
  POST per matching webhook (via `Xaas.Platform.Changes.DeliverWebhook`),
  running it via `after_action/2` held a real Postgres
  connection/transaction open for the full duration of that network
  round-trip. Under `mix test`'s real `async: true` sandbox pool (a fixed,
  small pool of checked-out connections shared across concurrent test
  processes), this starved unrelated concurrent tests of a connection,
  producing real cascading failures: `Attempted to update stale record of
  Xaas.Governance.ApprovalDrFailover`, `DBConnection.ConnectionError owner
  exited`, and `still using a connection from owner` (confirmed via a real
  `mix test` run before this fix, 8 real failures across unrelated test
  files).

  The fix: use `Ash.Changeset.after_transaction/2` instead. It runs after
  the parent `:approve` transaction has already committed (or rolled
  back), so the real HTTP dispatch no longer holds a database connection
  open. Fan-out (`WebhookDelivery` row creation) and dispatch (`:deliver`)
  both moved into this post-commit hook, since both were formerly nested
  inside the same over-broad `after_action` scope and neither needs the
  parent transaction's isolation -- the approved record is already
  durably committed by the time this hook runs, so reading `record`'s
  fields here is reading real, already-persisted data, not
  transaction-local uncommitted state.

  `after_transaction/2` only fires on a definite `{:ok, record}` or
  `{:error, reason}` outcome of the parent action, so on a real
  `:approve` failure no delivery is enqueued -- matching the original
  `after_action` behavior (which never ran on failure either, since
  `after_action` hooks only run on the success path).
  """
  use Ash.Resource.Change

  require Ash.Query
  require Logger
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

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      case result do
        {:ok, record} ->
          enqueue_deliveries(record, event_type)
          {:ok, record}

        {:error, error} ->
          {:error, error}
      end
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
      delivery =
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

      # Real outbound HTTP dispatch, right after persisting the row -- see
      # `Xaas.Platform.Changes.DeliverWebhook` for the real signing scheme
      # and real 2xx/non-2xx/transport-error handling. Runs post-commit
      # (see moduledoc), so this no longer holds the parent `:approve`
      # transaction's database connection open for the HTTP round-trip.
      delivery
      |> Ash.Changeset.for_update(:deliver, %{}, authorize?: false)
      |> Ash.update!()
    end)
  end
end
