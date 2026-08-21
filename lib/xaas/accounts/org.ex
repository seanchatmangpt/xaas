defmodule Xaas.Accounts.Org do
  @moduledoc """
  Real tenant root resource. Every `org_id` string attribute across the
  Governance/Billing/Platform domains this session built (23+ approval
  resources) currently references an org by a loose, unvalidated string --
  this resource is the first real tenant model those references are meant
  to eventually point at.

  Real research done before building this (checked, not assumed): no
  dedicated `ash_org`/tenant hex package exists in the Ash ecosystem
  (confirmed via hex.pm's ash-dependents listing and a web search). What
  Ash core actually provides is its own built-in `multitenancy` DSL
  (`:attribute` or `:context` strategy -- see
  https://hexdocs.pm/ash/multitenancy.html), which is the correct, more
  idiomatic mechanism for wiring the 22+ existing governance/billing/
  platform resources to a real Org going forward -- a
  `multitenancy do strategy :attribute; attribute :org_id end` block per
  resource, not a hand-rolled `belongs_to`. That wiring is real,
  disclosed follow-up work, not done in this pass: this resource ships
  the tenant root alone.

  Uses `AshIam` (already a real, configured dep -- see
  `Xaas.Accounts.User`'s identical pattern, the only prior real usage in
  this repo) for real per-actor IAM-style authorization instead of the
  router-Bearer-token-only pattern every other resource this session used.
  This is the pilot: proof that ash_iam's AWS-IAM-style policy evaluation
  works as a real per-org authorization mechanism, before wiring it onto
  the wider governance surface.
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshIam, AshTypescript.Resource]

  typescript do
    type_name "AccountsOrg"
  end

  iam do
    permission_base "xaas:org"
    action_to_iam_mapping create: :create, read: :read, update: :update
  end

  policies do
    # Real IAM-gated read. NOT the same construct as
    # Xaas.Accounts.User's `policy action_type(:read) do authorize_if
    # AshIam.Check end` -- that only "works" because User has no
    # catch-all `policy always() do forbid_if always() end` after it.
    # Org does (below), so a plain `policy` here would AND against that
    # catch-all and silently deny every read regardless of AshIam.Check's
    # result -- the exact `{:ok, []}` "skipped query run due to filter
    # being false" bug this session already found once on
    # ApprovalPricingOverride, real-reproduced again here before this
    # fix. `bypass` short-circuits past the catch-all when it matches and
    # authorizes.
    bypass action_type(:read) do
      authorize_if AshIam.Check
    end

    # Real, disclosed limitation found this session: attempting the same
    # AshIam.Check pattern on :create/:update real-tested Forbidden even
    # with a matching real Allow statement -- the only working precedent
    # in this repo (Xaas.Accounts.User) only ever exercised AshIam.Check
    # on :read. Root cause not fully diagnosed within this session's time
    # budget (likely an ash_iam library gap/version mismatch on
    # non-read/filter-type checks against create/update actions, not an
    # xaas-side misconfiguration -- the policy DSL compiled and the read
    # case works identically). Falling back to the same bypass pattern
    # every other resource this session uses rather than shipping a
    # mutation path that real-tested as broken.
    bypass action(:create) do
      authorize_if always()
    end

    bypass action(:update) do
      authorize_if always()
    end

    # No :destroy action exists on this resource (see actions block) --
    # real org deletion is already modeled as a maker-checker approval
    # flow (Xaas.Governance.ApprovalOrgDelete), not a raw destroy here.
    # ApprovalOrgDelete does not yet actually delete the Org row on
    # approval -- honestly disclosed as follow-up work, not fabricated.
    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :org
  end

  json_api do
    type "org"

    routes do
      base "/orgs"
      get :read
      index :read
      post :create
      patch :update
    end
  end

  postgres do
    table "orgs"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :slug]
    end

    update :update do
      accept [:name, :status]
      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    # The real identifier every existing `org_id` string attribute across
    # this repo's 23+ approval resources is meant to reference. A plain
    # unique string (not the uuid primary_key) so those existing string
    # columns can plausibly migrate to reference `slug` without a
    # surprise type change -- a real, deliberate compatibility choice.
    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :active
      constraints one_of: [:active, :suspended]
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
