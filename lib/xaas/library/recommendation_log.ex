defmodule Xaas.Library.RecommendationLog do
  @moduledoc """
  Ash resource for Recommendation Logs, storing candidate pool, factor weights, and produced recommendations.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table "library_recommendation_logs"
    repo Xaas.Repo
  end

  json_api do
    type "library_recommendation_log"

    routes do
      base "/library/recommendation_logs"
      get :read
      index :read
    end
  end

  graphql do
    type :library_recommendation_log
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:user_id, :candidate_pool_size, :weights, :ranked_items, :accepted]
    end

    update :update do
      primary? true
      accept [:accepted]
    end
  end

  policies do
    policy action_type(:read) do
      # Reads are open to any actor, including an unauthenticated guest
      # browsing persona (actor: nil) -- see
      # lib/xaas_web/a2a/next_read_user_agent.ex's documented guest-browse
      # design. No write/mutation surface is exposed to reads.
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      # Deny-by-default floor (CLAUDE.md): mutations require a real,
      # resolved actor. Callers with no actor (e.g. a guest persona) are
      # denied -- see next_read_user_agent.ex's checkout/2, which already
      # refuses to call Ash.create without a resolved actor.
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :candidate_pool_size, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :weights, :map do
      allow_nil? false
      default %{collab: 0.34, semantic: 0.26, gradeFit: 0.16, available: 0.10, diversity: 0.06, curation: 0.09}
      public? true
    end

    attribute :ranked_items, {:array, :map} do
      allow_nil? false
      default []
      public? true
    end

    attribute :accepted, :boolean do
      allow_nil? false
      default false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Xaas.Accounts.User do
      allow_nil? false
      attribute_writable? true
      public? true
    end
  end
end
