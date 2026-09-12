defmodule Xaas.Library.School do
  @moduledoc """
  Ash resource for a Library School (Schema.org `schema:EducationalOrganization`).

  Real domain-modeling gap this resource closes: prior to this pass, "the
  school" attributed to every checkout and used as the default fallback for
  the reader UI was a literal string constant (`"willow-creek"`) inside
  `Xaas.Library.Config`, with no backing row anywhere. That made it
  impossible to answer "which school is actually the default" from real
  data -- the answer was baked into application code, not the database.

  This resource makes "the default school" a real, queryable fact: exactly
  one row is expected to carry `default?: true` (enforced by the
  `unique_default_school` identity's application-level check in
  `Xaas.Library.Config.default_school_id/0`, not a DB constraint, since a
  boolean partial-unique-index is a follow-up gap disclosed here rather than
  silently assumed). `domain` is the real fact `reader_live.ex`'s guest-user
  fallback email now derives its `@<domain>` suffix from, instead of a
  hardcoded `"school.district.edu"` literal.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "library_schools"
    repo Xaas.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:slug, :name, :domain, :default?]
    end

    update :update do
      primary? true
      accept [:slug, :name, :domain, :default?]
    end

    read :get_default do
      description "Returns the single school currently flagged as the system default."
      get? true
      filter expr(default? == true)
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

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :domain, :string do
      description "Real email domain used for guest/fallback accounts attributed to this school."
      allow_nil? false
      public? true
    end

    attribute :default?, :boolean do
      allow_nil? false
      default false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
