defmodule Xaas.Library.Checkout do
  @moduledoc """
  Ash resource for Book Checkouts, grounded in Schema.org (schema:BorrowAction) and PROV (prov:Activity).
  Tracks circulation transactions of books borrowed by readers.
  """
  use Xaas.Resource,
    otp_app: :xaas,
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
    module XaasWeb.Endpoint
    prefix "circulation"
    broadcast_type :notification

    publish :create, ["school", :school_id]
    publish :create, ["events"]
    publish :create, ["student", :user_id]
    publish :borrow, ["events"]
    publish :borrow, ["student", :user_id]
    publish :return, ["events"]
    publish :return, ["student", :user_id]
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

    update :return do
      description "Marks a checkout as returned, automatically incrementing available copies"
      accept []
      # Xaas.Library.Changes.IncrementBookInventory does a non-atomic cross-
      # resource update (bumps the related Book's available_copies), which
      # Ash cannot express as a single atomic SQL statement -- same real
      # constraint as DecrementBookInventory on :borrow. Confirmed via a
      # real compile/test failure ("must be performed atomically") before
      # this was added.
      require_atomic? false
      change set_attribute(:status, :returned)
      change set_attribute(:returned_at, &DateTime.utc_now/0)
      change Xaas.Library.Changes.IncrementBookInventory
      # Charter gap close: after a return bumps inventory, hand the copy
      # straight to the oldest active hold on this book, if one exists.
      # Same after_action/transaction pattern as IncrementBookInventory --
      # deliberately not a Reactor/cascade (see Xaas.Library.Changes.FulfillNextHold).
      change Xaas.Library.Changes.FulfillNextHold
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
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
