defmodule Xaas.Library.Curation do
  @moduledoc """
  Ash resource for Librarian Curation, grounded in Schema.org (schema:Collection) and PROV (prov:Entity).
  Staff spotlight that boosts recommendation scores for specific grade bands or individual students.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table "library_curations"
    repo Xaas.Repo
  end

  pub_sub do
    module XaasWeb.Endpoint
    prefix "recommendations"
    broadcast_type :notification

    publish :create, ["student", :student_id]
    publish :create, ["curation_events"]
    publish :create, ["grade", :grade_band]
    publish :update, ["student", :student_id]
    publish :update, ["curation_events"]
    publish :update, ["grade", :grade_band]
  end

  json_api do
    type "library_curation"

    routes do
      base "/library/curations"
      get :read
      index :read
    end
  end

  graphql do
    type :library_curation
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:book_id, :curated_by, :grade_band, :student_id, :reason, :state, :active]
    end

    update :update do
      primary? true
      accept [:grade_band, :student_id, :reason, :state, :active]
    end

    read :active_for_grade do
      argument :grade_level, :integer, allow_nil?: false
      filter expr(active == true)
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

    attribute :curated_by, :string do
      allow_nil? false
      public? true
    end

    attribute :grade_band, :string do
      allow_nil? false
      default "6-8"
      public? true
    end

    attribute :student_id, :string do
      allow_nil? true
      public? true
    end

    attribute :reason, :string do
      allow_nil? true
      public? true
    end

    attribute :state, :atom do
      constraints [one_of: [:pinned, :promoted, :suppressed, :neutral]]
      default :pinned
      allow_nil? false
      public? true
    end

    attribute :active, :boolean do
      allow_nil? false
      default true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :book, Xaas.Library.Book do
      allow_nil? false
      attribute_writable? true
      public? true
    end
  end
end
