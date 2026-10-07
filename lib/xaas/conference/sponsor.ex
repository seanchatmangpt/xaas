defmodule Xaas.Conference.Sponsor do
  @moduledoc """
  One sponsor with a `tier` (`:diamond`/`:gold`/`:silver`/`:bronze`).
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
    type(:conference_sponsor)
  end

  json_api do
    type("conference_sponsor")

    routes do
      base("/conference/sponsors")
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

    attribute :tier, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:diamond, :gold, :silver, :bronze])
    end

    attribute(:url, :string, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_slug, [:slug], pre_check_with: Ash.DataLayer.Ets)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :slug, :tier, :url])
    end
  end
end
