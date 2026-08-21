defmodule Xaas.Marketplace.Provider do
  @moduledoc """
  Real, minimal marketplace-provider listing row -- a third-party service
  provider listed in a marketplace.

  ## Prior-art search: none found

  Task instructed searching `~/chatman-ecosystem/platform-console`'s real
  `app/` directory for prior marketplace/provider code to port from. Real
  hits exist there (`app/app/api/marketplace/[provider]/{register,usage,webhook}/route.ts`,
  `lib/marketplace-runtime.ts`), but that code is a different domain
  entirely: it registers a *cloud-marketplace purchase* (AWS/Azure/GCP
  Marketplace SaaS listings -- `MarketplaceProvider = "aws" | "azure" |
  "gcp"`) against this platform's own billing, linking a buyer/product/
  agreement/subscription ref from the cloud marketplace to an org. It has
  no row anywhere modeling "a third-party service provider listed in
  *our* marketplace" (name/slug/description/status) -- the closest
  concept, `MarketplaceProvider`, is a fixed 3-value literal type, not a
  data row. Honest conclusion: no real prior art to port business logic
  from for this specific shape. Every field below is therefore new,
  informed only by the task's own minimal honest shape (name, slug,
  description, status, org_id), not invented beyond that.

  ## org_id: loose string, not a real FK

  Same real, disclosed convention as every other `org_id` attribute in
  this repo (see `Xaas.Accounts.Org`'s own moduledoc and
  `Xaas.Billing.Subscription`'s `:org_id` attribute comment) -- real Ash
  multitenancy wiring is a separate, already-scoped pilot, not attempted
  here.

  ## AshIam read pilot -- removed this session (real, live-verified reason)

  Earlier this session this resource carried the same `AshIam` pilot as
  `Org`/`Subscription` (`bypass action_type(:read) do authorize_if
  AshIam.Check end`). Real, live-verified finding while wiring the real
  `:create`/`:update` mutation routes below: `ash_iam`'s transformer
  (`AshIam.Transformer.add_iam_field_policies/1`) unconditionally injects
  a real `field_policies do field_policy :* do authorize_if AshIam.Check
  end end` block for every public field on ANY resource using the `iam
  do ... end` DSL -- not opt-in, not scoped to the actions named in
  `action_to_iam_mapping`. Ash's field policies AND across all matching
  blocks (there is no field-level `bypass`), so that auto-injected block
  ANDs against every other field-authorization path unconditionally.
  Real repro: a real HTTP `GET`/`POST`/`PATCH` from a
  `KanbanWeb.Plugs.ResolveOrgActor`-resolved actor (`%{org_id: slug}`,
  not an IAM-permissioned actor) returned real `200`/`201` responses with
  every attribute serialized as `Ash.ForbiddenField` -> `null`
  (`"attributes":{}` in the raw JSON:API body) -- even though the
  action-level policy had already really authorized the request via
  `ActorOrgFilter`/`ActorOrgMatches`. There is no DSL option to disable
  `ash_iam`'s auto field-policy injection short of removing the `iam do
  ... end` block and the `AshIam` extension entirely. Since a real,
  customer-facing mutation API that can never return the row it just
  wrote is not a working feature, the `AshIam`/`iam do ... end` pilot was
  removed from this resource and `:read` now runs on the same real
  `Xaas.Marketplace.Checks.ActorOrgFilter` mechanism as `:create`/
  `:update` (see below) -- one real, working, field-visible
  actor-scoping design across all three actions, not two competing ones.
  This does not affect `Org`/`Subscription`'s own separate AshIam pilots;
  it is scoped to this resource only.

  ## Real customer-facing `:create`/`:update`/`:read` routes (this session)

  `:create`/`:update`/`:read` are all real, routed, and gated by
  `Xaas.Marketplace.Checks.ActorOrgFilter`/`ActorOrgMatches` (see those
  modules' moduledocs for the full disclosed design decision: a direct
  policy-expression check against `KanbanWeb.Plugs.ResolveOrgActor`'s
  real, caller-asserted `X-Org-Id` actor, NOT full Ash `multitenancy`
  DSL -- chosen as the smaller real diff needing no migration/FK).
  `marketplace_providers` was added to that plug's
  `@tenant_scoped_path_segments` so `X-Org-Id` resolution actually runs
  on this resource's routes.
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
      accept [:name, :slug, :description, :status, :org_id]
    end

    update :update do
      accept [:name, :description, :status]

      # Real, required: without this, AshJsonApi's PATCH route builds an
      # atomic update changeset whose `data` is
      # `Ash.Changeset.OriginalDataNotAvailable` at policy-evaluation
      # time -- `Xaas.Marketplace.Checks.ActorOrgMatches` then has no
      # real `org_id` to compare the actor against and correctly denies
      # (real, live-verified: a real HTTP PATCH from the SAME org's
      # actor 403'd even though an equivalent direct `Ash.update/1` call
      # with `require_atomic?: false` succeeded). Forcing the full
      # record to load first is the same real pattern
      # `ApprovalDrFailover`'s `:approve` action already uses.
      require_atomic? false
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

    # No real listing-review workflow designed yet -- three states
    # matching the task's own minimal shape. New for this resource, not
    # ported from anywhere (see moduledoc "prior-art search: none
    # found").
    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: [:pending, :active, :suspended]
    end

    # Loose string, same convention as `Xaas.Billing.Subscription.org_id`
    # -- the listing org, not a real FK.
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
