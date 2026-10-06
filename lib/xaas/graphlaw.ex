defmodule Xaas.Graphlaw do
  @moduledoc """
  Real Ash domain bringing graphlaw's engine-registry surface into xaas.

  The registry JSON (`capability-registry.json` in the graphlaw checkout) is
  the canonical semantic source; the resources here are its persisted
  projection. `Xaas.Graphlaw.Catalog.ingest/1` loads it; `limits_by_scope/1`
  reads back. Generated/consumer code never hand-maintains a second catalog.
  """
  use Ash.Domain,
    otp_app: :xaas,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Xaas.Graphlaw.EngineLimit)
    resource(Xaas.Graphlaw.Capability)
  end
end
