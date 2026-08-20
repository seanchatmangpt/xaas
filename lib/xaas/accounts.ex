defmodule Xaas.Accounts do
  use Ash.Domain, otp_app: :kanban


  resources do
    resource Xaas.Accounts.Token
    resource Xaas.Accounts.Token.RevokeNonce
    resource Xaas.Accounts.User
  end
end
