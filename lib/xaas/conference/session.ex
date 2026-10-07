defmodule Xaas.Conference.Session do
  @moduledoc """
  One scheduled conference session (talk/workshop/panel), scoped to a track
  via `track_id` and presented by a speaker via `speaker_id`.
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
    type(:conference_session)
  end

  json_api do
    type("conference_session")

    routes do
      base("/conference/sessions")
      get(:read)
      index(:read)
      post(:create)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute(:description, :string, public?: true)
    attribute(:track_id, :uuid, allow_nil?: false, public?: true)
    attribute(:speaker_id, :uuid, allow_nil?: false, public?: true)

    attribute(:starts_at, :utc_datetime, public?: true)
    attribute(:ends_at, :utc_datetime, public?: true)

    attribute :capacity, :integer do
      allow_nil?(true)
      public?(true)
      constraints(min: 1)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_slug, [:slug], pre_check_with: Ash.DataLayer.Ets)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:title, :slug, :description, :track_id, :speaker_id, :starts_at, :ends_at, :capacity])
    end
  end
end
