defmodule KanbanWeb.ApiRouter do
  @moduledoc """
  Token-protected AshJsonApi router for all seven configured XaaS domains.

  Routing remains resource-declared: mounting a domain here does not manufacture
  JSON:API actions. Sensitive Ledger and authentication resources that declare no
  routes remain unavailable through this router. Project measurement contributes
  one GET-only observation route and no CRUD actuation surface.
  """

  use AshJsonApi.Router,
    domains: [
      Xaas.Accounts,
      Xaas.Billing,
      Xaas.Governance,
      Xaas.Ledger,
      Xaas.Marketplace,
      Xaas.Operations,
      Xaas.Platform
    ],
    prefix: "/api"
end
