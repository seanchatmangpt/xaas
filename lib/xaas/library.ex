defmodule Xaas.Library do
  @moduledoc """
  Domain module for Library management (Books, Checkouts, Curations)
  grounded in Schema.org and BIBO ontologies.
  """
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Xaas.Library.Book
    resource Xaas.Library.Checkout
    resource Xaas.Library.Curation
  end
end
