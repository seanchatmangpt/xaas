defmodule Xaas.Marketplace.Provider do
  @moduledoc """
  Marketplace provider projection and customer-visible listing.

  The resource remains ordinary Ash CRUD for descriptive metadata, but provider
  lifecycle status is consequential state. Status transitions therefore have three
  separate internal per-transition actions (`:activate`, `:suspend`, `:reactivate`),
  each guarded by `Xaas.Actuation.Validations.ReactorContext` (authority -- was this
  actuated by an admitted `Ash.Reactor` intent/receipt) and each using
  `AshStateMachine`'s own built-in `transition_state/1` change, which refuses any
  transition not declared in the `state_machine` block below for free -- no custom
  structural-validity validation needed (an earlier version of this resource had one,
  `Xaas.Marketplace.Validations.ProviderStatusTransition`; an adversarial review found
  it existed only because status mutation had been modeled as one polymorphic action
  instead of one action per real target state, the idiomatic `AshStateMachine` shape
  already used elsewhere in this repo by
  `Xaas.Governance.ApprovalEnvironmentPromote`'s `:approve`/`:reject`). There is no
  JSON:API route for any of these three actions and `authorize?: false` alone cannot
  bypass either check.

  Like every `Xaas.Resource`, this resource is also projected onto public
  ontologies by `Xaas.Semantics.Registry`; the semantic projection hash is bound
  into every actuation intent and receipt.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Marketplace,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshTypescript.Resource, AshStateMachine]

  typescript do
    type_name "MarketplaceProvider"
  end

  # Declares the real, only-valid provider lifecycle graph, one action per real target
  # state -- the idiomatic AshStateMachine shape (see
  # Xaas.Governance.ApprovalEnvironmentPromote's :approve/:reject for the same pattern
  # in this repo). Each action's `change transition_state(:target)` below enforces
  # this graph for free via AshStateMachine.BuiltinChanges.TransitionState, which
  # internally calls AshStateMachine.Info.state_machine_transitions/2 -- no hand-written
  # validation needed.
  state_machine do
    initial_states([:pending])
    default_initial_state(:pending)
    state_attribute(:status)

    transitions do
      transition(:activate, from: :pending, to: :active)
      transition(:suspend, from: :active, to: :suspended)
      transition(:reactivate, from: :suspended, to: :active)
    end
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

    update :activate do
      public? false
      require_atomic? false
      validate Xaas.Actuation.Validations.ReactorContext
      change transition_state(:active)
    end

    update :suspend do
      public? false
      require_atomic? false
      validate Xaas.Actuation.Validations.ReactorContext
      change transition_state(:suspended)
    end

    update :reactivate do
      public? false
      require_atomic? false
      validate Xaas.Actuation.Validations.ReactorContext
      change transition_state(:active)
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
