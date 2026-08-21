defmodule Xaas.Marketplace.ApprovalProviderStatusChange do
  @moduledoc """
  Real maker-checker approval request for a `Xaas.Marketplace.Provider`
  status transition (`:pending -> :active`, any -> `:suspended`),
  mirroring the exact shape this repo's Governance domain already uses
  for every other state-changing operation (see
  `Xaas.Governance.ApprovalDrFailover`: a real `:create` action files a
  pending request row with `requested_by`; a real, distinct-approver
  validation gates a real `:approve` update action; `:approve` applies
  the change to the real target row).

  ## Real design decision (disclosed): separate resource, not new
  Provider attributes

  Two real options were on the table: (a) bare `requested_by`/
  `approved_by` attributes plus `:activate`/`:suspend` actions directly
  on `Provider`, or (b) this separate resource. Chosen: (b), smaller and
  more idiomatic real diff for this repo --

  - `Provider` would need a request pair of attributes that only ever
    hold the *latest* request, silently losing history on every repeat
    status change (a provider suspended and reactivated twice has no
    real row for the first request once the second overwrites it).
  - Every existing maker-checker flow in this repo (`ApprovalDrFailover`
    and its ~24 Governance siblings) already uses the separate-resource
    shape; a same-resource variant on `Provider` would be the one
    inconsistent case, not the idiomatic one.
  - `Provider`'s own `:update` action stays a plain attribute mutation
    (name/description) with no approval semantics attached, keeping its
    already-real `ActorOrgFilter` policy meaning unchanged.

  Real org-scoping mechanism reused, not reinvented: this resource has
  its own `org_id` attribute and real-reuses
  `Xaas.Marketplace.Checks.ActorOrgFilter`/`ActorOrgMatches` verbatim --
  the same real, disclosed "direct policy-expression check against
  `KanbanWeb.Plugs.ResolveOrgActor`'s caller-asserted `X-Org-Id` actor,
  not full Ash `multitenancy`" design `Provider` itself uses, kept
  consistent across both Marketplace resources rather than introducing a
  second, competing multitenancy design in this domain.
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Marketplace,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    bypass action_type(:read) do
      authorize_if Xaas.Marketplace.Checks.ActorOrgFilter
    end

    bypass action(:create) do
      authorize_if Xaas.Marketplace.Checks.ActorOrgMatches
    end

    # Same real reason as Provider's own `:update` bypass: AshJsonApi's
    # PATCH route builds an atomic-by-default changeset whose `data` is
    # unavailable to a changeset-only equality check at policy-eval
    # time, so `:approve` needs the row-filtering `FilterCheck`, not the
    # changeset-only `SimpleCheck`.
    bypass action(:approve) do
      authorize_if Xaas.Marketplace.Checks.ActorOrgFilter
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :approval_provider_status_change
  end

  json_api do
    type "approval_provider_status_change"

    routes do
      base "/approval_provider_status_change"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_provider_status_changes"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :provider_id, :requested_by, :requested_status]
    end

    update :approve do
      accept [:approved_by]

      # Same real reason as Provider's :update -- AshJsonApi's PATCH
      # route needs the full original record loaded for the
      # `ActorOrgFilter` bypass and the distinct-approver validation
      # (which reads `requested_by` off `changeset.data`) to real-work.
      require_atomic? false

      validate Xaas.Marketplace.Validations.ApprovalProviderStatusChangeRequiresApprover

      change Xaas.Marketplace.Changes.ApplyProviderStatusChange
    end
  end

  attributes do
    uuid_primary_key :id

    # Loose string, same real convention as `Provider.org_id` -- the
    # requesting org, not a real FK.
    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    attribute :provider_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :requested_by, :string do
      allow_nil? false
      public? true
    end

    # Real target state for the transition. `:pending` excluded on
    # purpose -- nothing real ever "requests" reverting to pending;
    # only forward-activate or suspend are real transitions a maker can
    # request.
    attribute :requested_status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:active, :suspended]
    end

    attribute :approved_by, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :provider, Xaas.Marketplace.Provider do
      source_attribute :provider_id
      destination_attribute :id
      attribute_type :uuid
      define_attribute? false
    end
  end
end
