defmodule Xaas.Marketplace do
  @moduledoc """
  Real, new Ash domain -- did not exist before this pass. Holds
  `Xaas.Marketplace.Provider`, the first resource in this namespace.
  """
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Xaas.Marketplace.Provider
  end
end
