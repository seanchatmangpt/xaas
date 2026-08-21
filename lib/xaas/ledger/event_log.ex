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
    # Real bug found and fixed this session: `record_id_type` defaults to
    # `:uuid`, but this event log is shared by both Xaas.Ledger.Account
    # (uuid_v7 primary key) and Xaas.Ledger.Transfer (AshDoubleEntry.ULID
    # primary key -- a ULID string, not a UUID). The first real
    # `Xaas.Ledger.Transfer.transfer` call ever exercised in this repo
    # failed with "Invalid value provided for record_id: is invalid" on a
    # real ULID value, because AshEvents tried to validate it as `:uuid`.
    # `:string` is the real fix -- it holds both a uuid_v7 string and a
    # ULID string correctly, since a single shared event log's record_id
    # column can't be two different strict types at once.
    record_id_type :string
    persist_actor_primary_key :user_id, Xaas.Accounts.User
  end
end
