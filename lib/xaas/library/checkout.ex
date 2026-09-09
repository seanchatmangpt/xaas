defmodule Xaas.Library.Checkout do
  @moduledoc """
  Ash resource for Book Checkouts, grounded in Schema.org (schema:BorrowAction) and PROV (prov:Activity).
  Tracks circulation transactions of books borrowed by readers.
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table "library_checkouts"
    repo Xaas.Repo
  end

  pub_sub do
    module KanbanWeb.Endpoint
    prefix "circulation"
    broadcast_type :notification

    publish :create, ["school", :school_id]
    publish :create, ["events"]
    publish :create, ["student", :user_id]
    publish :borrow, ["events"]
    publish :borrow, ["student", :user_id]
    publish :update, ["school", :school_id]
    publish :update, ["events"]
    publish :update, ["student", :user_id]
  end

  json_api do
    type "library_checkout"

    routes do
      base "/library/checkouts"
      get :read
      index :read
    end
  end

  graphql do
    type :library_checkout
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:book_id, :user_id, :school_id, :borrowed_at, :returned_at, :status, :renewed_count]
    end

    create :borrow do
      description "Borrows a book for a student, automatically decrementing available copies"
      accept [:book_id, :user_id, :school_id]
      change Xaas.Library.Changes.DecrementBookInventory
    end

    update :update do
      primary? true
      accept [:returned_at, :status, :renewed_count]
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

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type([:update, :destroy]) do
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

    attribute :borrowed_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :returned_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end

    attribute :renewed_count, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :status, :atom do
      constraints [one_of: [:borrowed, :returned, :overdue]]
      default :borrowed
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
