defmodule Xaas.Conference.Event do
  @moduledoc """
  AGNTCon+MCPCon 2026 — the single event record the rest of the conference
  surface hangs off of.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Conference,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  ets do
    private?(true)
  end

  graphql do
    type(:conference_event)

    # SPEC-31 (W819/W802-GAP-2; lane W973c design-wave 8): expose the
    # Conference domain on Xaas.GraphqlSchema. Read-only; the resource's
    # real Ash policies still gate every resolution.
    queries do
      get(:conference_event, :read)
      list(:conference_events, :read)
    end
  end

  json_api do
    type("conference_event")

    routes do
      base("/conference/events")
      get(:read)
      index(:read)
      post(:create)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute(:location, :string, public?: true)

    attribute(:starts_at, :utc_datetime, public?: true)
    attribute(:ends_at, :utc_datetime, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_slug, [:slug], pre_check_with: Ash.DataLayer.Ets)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :slug, :location, :starts_at, :ends_at])
    end
  end
end
