defmodule Xaas.Marketplace do
  @moduledoc """
  Real, new Ash domain -- did not exist before this pass. Holds
  `Xaas.Marketplace.Provider`, the first resource in this namespace.
  """
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource Xaas.Marketplace.Provider do
      rpc_action :list_marketplace_providers, :read
    end
  end

  resources do
    resource Xaas.Marketplace.Provider
  end
end
