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

  ## AshIam read bypass -- same real pilot as Org/Subscription

  Extended into the real AshIam pilot begun on `Xaas.Accounts.Org` and
  `Xaas.Billing.Subscription`: `:read` now bypasses the catch-all via
  `bypass action_type(:read) do authorize_if AshIam.Check end`, the same
  construct proven working on Org/Subscription (a plain `policy` here
  would AND against the trailing `policy always() do forbid_if always()
  end` catch-all and silently deny every read regardless of
  `AshIam.Check`'s result -- see Org's moduledoc for the real
  `{:ok, []}` bug this was found from).

  `:create`/`:update` are deliberately NOT wired to `AshIam.Check` --
  the same real, disclosed limitation as Org/Subscription: this
  repo's `ash_iam` version real-tests as broken on non-read/filter-type
  checks against create/update actions. They stay behind the existing
  `policy always() do forbid_if always() end` catch-all exactly as
  before this change; `authorize?: false` (used in this resource's own
  Chicago-style tests, matching every other resource's test convention
  in this repo) remains the only way to exercise them today.
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Marketplace,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshIam]

  iam do
    permission_base "xaas:marketplace_provider"
    action_to_iam_mapping create: :create, read: :read, update: :update
  end

  policies do
    bypass action_type(:read) do
      authorize_if AshIam.Check
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
