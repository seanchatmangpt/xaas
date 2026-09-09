defmodule Xaas.Library.Book do
  @moduledoc """
  Ash resource for Library Books, grounded in BIBO (bibo:Book) and Schema.org (schema:Book).
  Represents library items with ISBN, grade-level reading fit, genres, formats, and availability.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshAdmin.Resource]

  postgres do
    table "library_books"
    repo Xaas.Repo
  end

  admin do
    # `embedding` is a raw {:array, :float} vector (hundreds of floats) --
    # AshAdmin's default table_columns is every attribute, which would
    # render this as an unreadable wall of numbers in the datatable. Hide
    # it from the table view; it remains a normal, readable/writable
    # attribute everywhere else (API, GraphQL, show/edit forms).
    table_columns [
      :id,
      :title,
      :author,
      :isbn,
      :grade_level,
      :genres,
      :formats,
      :available_copies,
      :total_copies,
      :review_status,
      :inserted_at,
      :updated_at
    ]
  end

  pub_sub do
    module XaasWeb.Endpoint
    prefix "library:books"
    broadcast_type :notification

    publish :create, ["created"]
    publish :create, ["events"]
    publish :update, ["updated", :id]
    publish :update, ["events"]
    publish :borrow_copy, ["inventory", :id]
    publish :borrow_copy, ["events"]
    publish :return_copy, ["inventory", :id]
    publish :return_copy, ["events"]
  end

  json_api do
    type "library_book"

    routes do
      base "/library/books"
      get :read
      index :read
    end
  end

  graphql do
    type :library_book

    queries do
      get :library_book, :read
      list :library_books, :read
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [
        :title,
        :author,
        :isbn,
        :grade_level,
        :genres,
        :formats,
        :synopsis,
        :available_copies,
        :total_copies,
        :cover_color,
        :review_status,
        :embedding
      ]
    end

    update :update do
      primary? true
      accept [
        :title,
        :author,
        :isbn,
        :grade_level,
        :genres,
        :formats,
        :synopsis,
        :available_copies,
        :total_copies,
        :cover_color,
        :review_status,
        :embedding
      ]
    end

    update :borrow_copy do
      description "Atomically decrements available shelf copies when checked out"
      validate compare(:available_copies, greater_than: 0), message: "No shelf copies currently available"
      change atomic_update(:available_copies, expr(available_copies - 1))
    end

    update :return_copy do
      description "Atomically increments available shelf copies when returned"
      change atomic_update(:available_copies, expr(available_copies + 1))
    end

    read :by_grade_band do
      argument :min_grade, :integer, allow_nil?: false
      argument :max_grade, :integer, allow_nil?: false

      filter expr(grade_level >= ^arg(:min_grade) and grade_level <= ^arg(:max_grade))
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

  aggregates do
    count :active_checkouts_count, :checkouts do
      filter expr(status == :borrowed)
    end

    count :active_holds_count, :holds do
      filter expr(status == :active)
    end
  end

  calculations do
    calculate :is_available, :boolean, expr(available_copies > 0)
    calculate :has_multiple_copies, :boolean, expr(available_copies > 1)
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :author, :string do
      allow_nil? false
      public? true
    end

    attribute :isbn, :string do
      allow_nil? true
      public? true
    end

    attribute :grade_level, :decimal do
      allow_nil? false
      default Decimal.new("5.0")
      public? true
    end

    attribute :genres, {:array, :string} do
      allow_nil? false
      default []
      public? true
    end

    attribute :formats, {:array, :string} do
      allow_nil? false
      default ["Print"]
      public? true
    end

    attribute :synopsis, :string do
      allow_nil? true
      public? true
    end

    attribute :available_copies, :integer do
      allow_nil? false
      default 1
      public? true
    end

    attribute :total_copies, :integer do
      allow_nil? false
      default 1
      public? true
    end

    attribute :cover_color, :string do
      allow_nil? false
      default "#23405F"
      public? true
    end

    attribute :review_status, :atom do
      constraints [one_of: [:approved, :pending_librarian_review]]
      default :approved
      allow_nil? false
      public? true
    end

    attribute :embedding, {:array, :float} do
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :checkouts, Xaas.Library.Checkout
    has_many :holds, Xaas.Library.HoldRequest
    has_many :curations, Xaas.Library.Curation
  end
end
