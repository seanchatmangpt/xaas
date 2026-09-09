defmodule Xaas.Library.Book do
  @moduledoc """
  Ash resource for Library Books, grounded in BIBO (bibo:Book) and Schema.org (schema:Book).
  Represents library items with ISBN, grade-level reading fit, genres, formats, and availability.
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table "library_books"
    repo Xaas.Repo
  end

  pub_sub do
    module KanbanWeb.Endpoint
    prefix "library:books"
    broadcast_type :notification

    publish :create, ["created"]
    publish :update, ["updated", :id]
    publish :borrow_copy, ["inventory", :id]
    publish :return_copy, ["inventory", :id]
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
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if always()
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
