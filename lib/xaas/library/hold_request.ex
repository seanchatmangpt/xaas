defmodule Xaas.Library.HoldRequest do
  @moduledoc """
  Ash resource for Hold Requests on library books, grounded in Schema.org (schema:ReserveAction) and PROV (prov:Activity).
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table "library_holds"
    repo Xaas.Repo
  end

  pub_sub do
    module KanbanWeb.Endpoint
    prefix "holds"
    broadcast_type :notification

    publish :create, ["created"]
    publish :update, ["updated", :id]
  end

  json_api do
    type "library_hold"

    routes do
      base "/library/holds"
      get :read
      index :read
    end
  end

  graphql do
    type :library_hold
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:book_id, :user_id, :school_id, :position, :status]
    end

    update :update do
      primary? true
      accept [:position, :status]
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :school_id, :string do
      allow_nil? false
      default "willow-creek"
      public? true
    end

    attribute :position, :integer do
      allow_nil? false
      default 1
      public? true
    end

    attribute :status, :atom do
      constraints [one_of: [:active, :fulfilled, :cancelled]]
      default :active
      allow_nil? false
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

    belongs_to :user, Xaas.Accounts.User do
      allow_nil? false
      attribute_writable? true
      public? true
    end
  end
end
