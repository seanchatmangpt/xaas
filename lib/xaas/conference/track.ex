defmodule Xaas.Conference.Track do
  @moduledoc """
  One conference track (e.g. "Agents in Production"), scoped to an event via
  `event_id`.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Conference,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  ets do
    private?(true)
  end

  json_api do
    type("conference_track")

    routes do
      base("/conference/tracks")
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

    attribute(:description, :string, public?: true)
    attribute(:event_id, :uuid, allow_nil?: false, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_slug, [:slug], pre_check_with: Ash.DataLayer.Ets)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :slug, :description, :event_id])
    end
  end
end
