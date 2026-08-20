defmodule Xaas.Ledger.EventLog.ClearAllRecords do
  @moduledoc """
  Clears ledger records before an AshEvents replay rebuilds state from the
  event log. Deletes rows directly via the repo (not the resources' Ash
  actions) so replay starts from a genuinely empty table, matching the
  ash_events replay contract.
  """

  use AshEvents.ClearRecordsForReplay

  @impl true
  def clear_records!(_opts) do
    Xaas.Repo.delete_all(Xaas.Ledger.Balance)
    Xaas.Repo.delete_all(Xaas.Ledger.Transfer)
    Xaas.Repo.delete_all(Xaas.Ledger.Account)
    :ok
  end
end
