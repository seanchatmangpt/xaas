defmodule Xaas.Conference.Speaker do
  @moduledoc """
  One confirmed speaker on the AGNTCon+MCPCon 2026 roster.
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
    type(:conference_speaker)
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
    # Lane W975b (design-wave 4, SPEC-30 mount repair, fix verified by
    # W978b's receipt): the name `keynote?` is not a legal GraphQL field
    # name (~r/^[_A-Za-z][_0-9A-Za-z]*$/), so any schema compile that
    # includes Xaas.Conference dies in Absinthe.Schema.__after_compile__/2
    # with "Field name keynote? has invalid characters". `public?: false`
    # removes the attribute from GraphQL (and JSON:API) projections --
    # resource behavior (accept lists, ETS, direct reads) is unchanged.
    # A GraphQL-visible rename is disclosed follow-up.
    attribute(:keynote?, :boolean, allow_nil?: false, public?: false, default: false)

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
