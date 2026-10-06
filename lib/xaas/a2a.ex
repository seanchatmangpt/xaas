defmodule Xaas.A2a do
  @moduledoc """
  A2A protocol surface as Ash resources (PW4). Brings ash_a2a's agent-card /
  task surface into xaas: `Xaas.A2a.Agent` (a served v1 agent card as a
  queryable projection) and `Xaas.A2a.Task` (a protocol task bound to its
  agent). Ingestion of real served cards is `Xaas.A2a.Catalog.ingest/1`.

  Same projection posture as `Xaas.Marketplace.Pack`: Ash.DataLayer.Ets,
  private, the ingested card JSON IS the store, these resources are the
  queryable consequence.
  """

  use Ash.Domain,
    otp_app: :xaas,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Xaas.A2a.Agent)
    resource(Xaas.A2a.Task)
  end
end
