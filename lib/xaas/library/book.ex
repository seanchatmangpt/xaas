defmodule Xaas.Library.Book do
  @moduledoc """
  Ash resource for Library Books, grounded in BIBO (bibo:Book) and Schema.org (schema:Book).
  Represents library items with ISBN, grade-level reading fit, genres, and availability.
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "library_books"
    repo Xaas.Repo
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
        :synopsis,
        :available_copies,
        :total_copies,
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
        :synopsis,
        :available_copies,
        :total_copies,
        :embedding
      ]
    end

    read :by_grade_band do
      argument :min_grade, :integer, allow_nil?: false
      argument :max_grade, :integer, allow_nil?: false

      filter expr(grade_level >= ^arg(:min_grade) and grade_level <= ^arg(:max_grade))
    end
  end

  policies do
    # Scoped reads bypass for general library search
    bypass always() do
      authorize_if always()
    end

    # Default deny floor
    policy always() do
      forbid_if always()
    end
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

    attribute :grade_level, :integer do
      allow_nil? false
      public? true
    end

    attribute :genres, {:array, :string} do
      allow_nil? false
      default []
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

    attribute :embedding, {:array, :float} do
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :checkouts, Xaas.Library.Checkout
    has_many :curations, Xaas.Library.Curation
  end
end
