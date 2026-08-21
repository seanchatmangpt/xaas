defmodule Xaas.Accounts do
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain]

  admin do
    show? true
  end


  resources do
    resource Xaas.Accounts.Org
    resource Xaas.Accounts.Token
    resource Xaas.Accounts.Token.RevokeNonce
    resource Xaas.Accounts.User
  end
end
