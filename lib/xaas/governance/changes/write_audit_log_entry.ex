defmodule Xaas.Governance.Changes.WriteAuditLogEntry do
  @moduledoc """
  Real, reusable Ash change: after a Governance `Approval*` resource's
  `:approve` action succeeds, writes one real
  `Xaas.Operations.AuditLogEntry` row recording who did what, when.

  Reused verbatim across the wired `:approve` actions via
  `change {__MODULE__, action: "...", resource_type: "..."}`.

  ## Real fix: `after_action/2`, not `after_transaction/2` (corrected --
  this module previously got this backwards, the exact same bug round 7
  (`aec265a`) already found and fixed on 3 sibling Ledger-writing
  changes, on this 4th resource that round's diff never touched)

  This module originally used `after_transaction/2`, citing
  `Xaas.Governance.Changes.EnqueueWebhookDeliveries`'s real
  transaction-boundary lesson as precedent. That lesson is specifically
  about not holding a DB transaction/connection open across *blocking
  I/O to an external system* (a real outbound HTTP webhook POST) -- it
  does not apply here. This change's own work is a second, purely
  internal write to the *same* Postgres database, and
  `after_transaction/2` only ever runs once the parent `:approve`
  transaction has already, durably committed. Combined with the old
  `write_entry/3` calling `Ash.create!/2` (the bang variant, which
  *raises* instead of returning `{:error, _}`), a real `AuditLogEntry`
  write failure there crashed the request *after* the approval was
  already permanently persisted: the caller saw a 500 that looks like
  the approval itself failed, when in fact it had already succeeded and
  was simply left un-audited forever, with no compensating action and
  no way to roll the approval back after the fact.

  `Ash.Changeset.after_action/2` runs *inside* the parent `:approve`
  transaction (real Ash source, `deps/ash/lib/ash/changeset/changeset.ex`'s
  `transaction_hooks/2`) and a `{:error, _}` return from it rolls the
  whole transaction back -- including the approval write itself. This is
  the exact same real, already-proven-working pattern
  `Xaas.Billing.Changes.ApprovalSlaCreditApplyApprove` (and its two
  Ledger-writing siblings) now use. `write_entry/3` was switched from
  `Ash.create!/2` to `Ash.create/2` (non-bang) so a real failure returns
  `{:error, _}` -- the value that actually rolls the transaction back --
  instead of raising.
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

    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      case write_entry(record, action, resource_type) do
        {:ok, _entry} -> {:ok, record}
        {:error, error} -> {:error, error}
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
    |> Ash.create()
  end
end
