defmodule KanbanWeb.ApiRouter do
  @moduledoc """
  Real, customer-facing AshJsonApi.Router mounted for all 6 real domains.

  Only ever serves what each resource has explicitly declared via its own
  real `json_api do routes do ... end end` block -- adding a domain here
  does not itself expose anything; 44 of 49 real resources now declare a
  real, safe, read-only default (`get :read` / `index :read`) added
  mechanically this session. 5 were deliberately excluded from that
  mechanical pass and have NO routes declared, so mounting their domains
  here is still safe:

  - `Xaas.Ledger.Balance`/`Account`/`Transfer`: real double-entry
    financial ledger data. Exposing it needs a real access-control
    design (whose balance can whom see?), not a generic open read.
  - `Xaas.Accounts.User`/`Token`: real auth/PII (Token holds cloaked
    `extra_data`). Same reasoning.

  Mutating routes (create/update/destroy) were deliberately NOT added
  for any resource -- every one of the 44 only got `get`/`index` on
  `:read`, since a real create/update/destroy route requires a real
  business decision (which action, what input validation, what auth)
  that a mechanical pass cannot make. This still leaves the standing
  `docs/ASH-MIGRATION-PLAN.md` Phase 5 item 2 decision (real
  customer-facing *mutation* surface) genuinely open, not resolved by
  this router.
  """

  use AshJsonApi.Router,
    domains: [
      Xaas.Accounts,
      Xaas.Billing,
      Xaas.Governance,
      Xaas.Ledger,
      Xaas.Operations,
      Xaas.Platform
    ],
    prefix: "/api"
end
