defmodule Xaas.Library.Curation do
  @moduledoc """
  Ash resource for Librarian Curation, grounded in Schema.org (schema:Collection) and PROV (prov:Entity).
  Staff spotlight that boosts recommendation scores for specific grade bands.
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "library_curations"
    repo Xaas.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:book_id, :curated_by, :grade_band, :reason, :active]
    end

    update :update do
      primary? true
      accept [:grade_band, :reason, :active]
    end

    read :active_for_grade do
      argument :grade_level, :integer, allow_nil?: false
      filter expr(active == true)
    end
  end

  policies do
    bypass always() do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
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
      public? true
    end

    attribute :reason, :string do
      allow_nil? true
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
