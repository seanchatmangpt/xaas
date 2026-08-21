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

  ## Deny-by-default floor (per CLAUDE.md) -- MORE conservative than Subscription

  This resource has no real access-control design yet at all, not even a
  read carve-out. Unlike `Xaas.Billing.Subscription` (which bypasses
  `:read` via `AshIam.Check`, the real pilot pattern proven on
  `Xaas.Accounts.Org`), this resource has no actor-scoping rule designed
  -- there is no real notion yet of "which org/actor may list which
  providers." Per the task's own explicit instruction, `:read` stays
  behind the plain `policy always() do forbid_if always() end` catch-all
  too, matching `Xaas.Billing.Subscription`'s own conservative treatment
  of its `:create`/`:sync_from_stripe` actions (real actions that exist,
  real JSON:API routes that route to them, but zero policy bypass, so
  every real call -- through the JSON:API or direct `Ash.read!` with a
  real actor -- is denied until a real authorization rule is designed).
  `authorize?: false` (used in this resource's own Chicago-style tests,
  matching every other resource's test convention in this repo) is the
  only way to exercise these actions today; that is the disclosed,
  intentional state of this resource as shipped in this pass.
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Marketplace,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
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
