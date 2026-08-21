defmodule Xaas.Accounts do
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource Xaas.Accounts.Org do
      rpc_action :list_accounts_orgs, :read
    end
  end


  resources do
    resource Xaas.Accounts.Org
    resource Xaas.Accounts.OrgMembership
    resource Xaas.Accounts.Token
    resource Xaas.Accounts.Token.RevokeNonce
    resource Xaas.Accounts.User
  end
end
