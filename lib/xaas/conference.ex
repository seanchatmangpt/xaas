defmodule Xaas.Conference do
  @moduledoc """
  Real, new Ash domain for the AGNTCon+MCPCon 2026 conference surface:
  `Xaas.Conference.{Event, Track, Session, Speaker, Sponsor, Attendee,
  Registration}`.

  Every resource uses `Ash.DataLayer.Ets` (private tables) — the conference
  roster is a bounded, per-runtime projection seeded per-environment, so
  durable Postgres storage would buy nothing. Like `Xaas.Marketplace.Pack`,
  this is a queryable projection, not a system of record.
  """
  use Ash.Domain,
    otp_app: :xaas,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Xaas.Conference.Event)
    resource(Xaas.Conference.Track)
    resource(Xaas.Conference.Session)
    resource(Xaas.Conference.Speaker)
    resource(Xaas.Conference.Sponsor)
    resource(Xaas.Conference.Attendee)
    resource(Xaas.Conference.Registration)
  end
end
