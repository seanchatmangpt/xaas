defmodule Xaas.Ledger do
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshAdmin.Domain]

  resources do
    resource Xaas.Ledger.Account
    resource Xaas.Ledger.Balance
    resource Xaas.Ledger.Transfer
    resource Xaas.Ledger.EventLog
  end
end
