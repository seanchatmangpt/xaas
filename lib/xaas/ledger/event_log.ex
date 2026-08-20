defmodule Xaas.Ledger.EventLog do
  @moduledoc """
  Central event log for the Xaas.Ledger domain. Persists every create/update
  action on ledger resources (Account, Transfer, Balance) that opt into
  event tracking via `AshEvents.Events`, giving the ledger a real audit
  trail and replay capability on top of the existing ash_double_entry
  transaction model.
  """

  use Ash.Resource,
    otp_app: :kanban,
    domain: Xaas.Ledger,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "ledger_events"
    repo Xaas.Repo
  end

  event_log do
    clear_records_for_replay Xaas.Ledger.EventLog.ClearAllRecords
    primary_key_type Ash.Type.UUIDv7
    persist_actor_primary_key :user_id, Xaas.Accounts.User
  end
end
