defmodule Xaas.Conference.Speaker do
  @moduledoc """
  One confirmed speaker on the AGNTCon+MCPCon 2026 roster.
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
    type("conference_speaker")

    routes do
      base("/conference/speakers")
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

    attribute(:bio, :string, public?: true)
    attribute(:keynote?, :boolean, allow_nil?: false, public?: true, default: false)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_slug, [:slug], pre_check_with: Ash.DataLayer.Ets)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :slug, :bio, :keynote?])
    end
  end
end
