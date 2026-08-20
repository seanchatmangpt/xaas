defmodule KanbanWeb.InternalApiRouter do
  @moduledoc """
  Real, minimal AshJsonApi.Router mounted only for `Xaas.Operations` --
  scoped to internal self-observability resources with an explicit
  `json_api do routes do ... end end` block (currently just
  `Xaas.Operations.CapabilityLivenessReceipt`'s real read-only routes).

  Deliberately narrower than the standing, deferred "wire the real
  customer-facing API surface for all 49 resources" decision
  (`docs/ASH-MIGRATION-PLAN.md` Phase 5 item 2) -- this router only ever
  serves routes that resources have opted into via their own real
  `json_api do routes do ... end end` block, so adding this router does
  not itself expose anything beyond what's already been explicitly
  declared resource-by-resource.
  """

  use AshJsonApi.Router,
    domains: [Xaas.Operations],
    prefix: "/internal-api"
end
