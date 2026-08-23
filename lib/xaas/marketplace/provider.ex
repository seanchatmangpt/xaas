defmodule Xaas.Marketplace.Provider do
  @moduledoc """
  Marketplace provider projection and customer-visible listing.

  The resource remains ordinary Ash CRUD for descriptive metadata, but provider
  lifecycle status is consequential state. Status transitions therefore have a
  separate internal `:actuate_status` action guarded by
  `Xaas.Actuation.Validations.ReactorContext`. There is no JSON:API route for that
  action and `authorize?: false` alone cannot bypass the validation: the action
  requires a live intent/receipt context manufactured by `Xaas.Actuation.Reactor`.

  Like every `Xaas.Resource`, this resource is also projected onto public
  ontologies by `Xaas.Semantics.Registry`; the semantic projection hash is bound
  into every actuation intent and receipt.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Marketplace,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshTypescript.Resource]

  typescript do
    type_name "MarketplaceProvider"
  end

  policies do
    bypass action_type(:read) do
      authorize_if Xaas.Marketplace.Checks.ActorOrgFilter
    end

    bypass action(:create) do
      authorize_if Xaas.Marketplace.Checks.ActorOrgMatches
    end

    bypass action(:update) do
      authorize_if Xaas.Marketplace.Checks.ActorOrgFilter
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :marketplace_provider
  end

  json_api do
    type "marketplace_provider"

    routes do
      base "/marketplace_providers"
      get :read
      index :read
      post :create
      patch :update
    end
  end

  postgres do
    table "marketplace_providers"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      # New providers always enter the lifecycle at the attribute default
      # (:pending). Construction cannot smuggle an already-actuated status.
      accept [:name, :slug, :description, :org_id]
    end

    update :update do
      # Lifecycle status is intentionally absent. Public/customer mutation may
      # change descriptive metadata but cannot actuate provider lifecycle.
      accept [:name, :description]
      require_atomic? false
    end

    update :actuate_status do
      public? false
      accept [:status]
      require_atomic? false
      validate Xaas.Actuation.Validations.ReactorContext
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: [:pending, :active, :suspended]
    end

    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
