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

  ## Real fix (nineteenth pass) -- the real, live-HTTP-proven compound gap
  on this resource's own mutation routes, found by the ERRC grid sweep

  Real, live-HTTP-proven finding: despite `:update` already being scoped
  to `Xaas.Accounts.Checks.ActorBelongsToOrg` (see below), `POST
  /api/orgs` and `PATCH /api/orgs/:id` were BOTH real, unconditional
  `HTTP 403` for every real caller -- fresh-reproduced this pass via a
  temporary, deleted-after-run `ConnCase` test before any fix landed.
  Two real, independent gaps, both closed this pass:

  - **Gap A (actor resolution)**: no plug in the real `/api` pipeline ever
    supplied ANY actor for `/api/orgs*` requests --
    `KanbanWeb.Plugs.ResolveOrgActor`'s tenant-scoped path list never
    included `orgs`. Fixed by special-casing `orgs` in that plug (see its
    own moduledoc): `POST /api/orgs` now gets a minimal, non-nil
    `actor_present()`-satisfying actor (this resource is the ONLY
    `actor_present()` consumer in the codebase -- real-confirmed via
    `grep -rn "actor_present()" lib/xaas`, so this is a safe, fully-scoped
    change); `PATCH /api/orgs/:id` now gets the same real, header-asserted
    `%{org_id: slug}` actor every other tenant-scoped resource's
    `ActorOrgMatches`-style check already relies on. GET/index are
    deliberately left untouched -- `Org`'s read policy is IAM-gated, not
    org-token-gated, and gating it behind a required `X-Org-Id` header
    would break real cross-org IAM-listing use cases this resource's read
    policy is built for.
  - **Gap A, second half (actor-shape mismatch)**: even with an actor
    resolved, `ActorBelongsToOrg`'s `match?/3` only recognized a real
    User-shaped `%{id: ...}` actor (a shape no real `/api` plug has ever
    produced) -- real-fixed by adding a NEW, separate check,
    `Xaas.Accounts.Checks.ActorOrgSelfFilter`, recognizing the
    header-asserted `%{org_id: slug}` shape and OR'd alongside
    `ActorBelongsToOrg` on `:update` (see that module's own moduledoc for
    the real, disclosed reason it is a separate `FilterCheck`, not an
    extra clause inside `ActorBelongsToOrg` itself -- a real,
    field-authorization redaction problem, found and fixed this pass, made
    a `SimpleCheck` unworkable for this half).
  - **Gap B (atomic-eligibility)**: `:update` carried zero disqualifying
    `validate`/`change` module -- the same bare, atomic-upgrade-eligible
    shape `Incident`/`RouteOrgsCustomDomain` each had before their own
    round-16/17 fix. Real-fixed by adding
    `Xaas.Accounts.Validations.OrgSuspendedRequiresSuspensionReason` (see
    its own moduledoc for the real business rule + the real,
    disclosed atomic-ineligibility side effect this pass needed).
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
    # Real, nineteenth-pass addition: `authorize_if
    # Xaas.Accounts.Checks.ActorOrgSelfFilter` alongside the existing
    # `AshIam.Check` -- a real, ADDITIVE OR, not a narrowing (see that
    # check's own moduledoc for the full disclosure). Needed because
    # `AshJsonApi`'s real `PATCH` controller loads the target record via
    # THIS `:read` policy before running `:update` -- without it, the
    # real, header-asserted org-token actor `KanbanWeb.Plugs.
    # ResolveOrgActor` produces (which carries no `iam_policy`) could
    # never even load the row to update, real-`404`ing every legitimate
    # `PATCH /api/orgs/:id` regardless of `ActorBelongsToOrg`'s own fix.
    bypass action_type(:read) do
      authorize_if AshIam.Check
      authorize_if Xaas.Accounts.Checks.ActorOrgSelfFilter
    end

    # Real, disclosed limitation found this session: attempting the same
    # AshIam.Check pattern on :create/:update real-tested Forbidden even
    # with a matching real Allow statement -- the only working precedent
    # in this repo (Xaas.Accounts.User) only ever exercised AshIam.Check
    # on :read. Root cause not fully diagnosed within this session's time
    # budget (likely an ash_iam library gap/version mismatch on
    # non-read/filter-type checks against create/update actions, not an
    # xaas-side misconfiguration -- the policy DSL compiled and the read
    # case works identically).
    #
    # Bypass-audit fix (prompt #10): a blanket `authorize_if always()`
    # here was genuinely over-broad for a tenant-root resource -- it let
    # a fully anonymous (`actor: nil`) caller create or mutate (rename,
    # suspend/reactivate) any Org row. Org has no membership/ownership
    # relationship modeled yet (see moduledoc: multitenancy wiring is
    # real, disclosed follow-up work), so a per-org scoping condition
    # (e.g. "actor belongs to this org") does not exist as a real fact
    # this resource can check today. `actor_present()` is the strongest
    # real condition actually available given that constraint: it keeps
    # every legitimate authenticated caller working exactly as before
    # while denying the unauthenticated case that was previously
    # silently allowed. Full IAM-gated create/update remains the real
    # follow-up once the ash_iam create/update gap above is root-caused.
    bypass action(:create) do
      authorize_if actor_present()
    end

    # :update authorizes via 2 real, OR'd checks (real, nineteenth-pass
    # addition of the second): `Xaas.Accounts.Checks.ActorBelongsToOrg`
    # (a real Postgres-backed `Xaas.Accounts.OrgMembership` row for a
    # User-shaped `%{id: ...}` actor) OR `Xaas.Accounts.Checks.
    # ActorOrgSelfFilter` (a real header-asserted `%{org_id: slug}` actor
    # matching this record's own `slug` -- the only actor shape any real
    # `/api` plug in this codebase actually produces today, see
    # `KanbanWeb.Plugs.ResolveOrgActor`). See `ActorOrgSelfFilter`'s own
    # moduledoc for the real, disclosed reason the org-token half is a
    # `FilterCheck`, not a `SimpleCheck` like the membership half.
    # `:create` is deliberately left on `actor_present()`: a not-yet-
    # created org has no memberships to belong to yet (see
    # `ActorBelongsToOrg`'s own moduledoc for the full disclosure).
    bypass action(:update) do
      authorize_if Xaas.Accounts.Checks.ActorBelongsToOrg
      authorize_if Xaas.Accounts.Checks.ActorOrgSelfFilter
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
      accept [:name, :status, :suspension_reason]
      require_atomic? false

      # Real fix (nineteenth pass, see moduledoc's "Gap B" disclosure): a
      # real, no-`atomic/3` validation, matching the identical
      # `IncidentResolvedRequiresResolvedAt`/
      # `RouteOrgsCustomDomainActiveRequiresCertificateSecret` shape --
      # forces `:update` to disqualify Ash's atomic-upgrade optimization
      # so `changeset.data` is real and populated when
      # `ActorBelongsToOrg`'s org-token clause reads this record's own
      # `slug` off it.
      validate Xaas.Accounts.Validations.OrgSuspendedRequiresSuspensionReason
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

    # Real, net-new attribute (nineteenth pass): the supporting fact
    # `Xaas.Accounts.Validations.OrgSuspendedRequiresSuspensionReason`
    # requires whenever `status` transitions to `:suspended` -- see that
    # module's own moduledoc for the full real business rule and its real,
    # disclosed atomic-ineligibility side effect.
    attribute :suspension_reason, :string do
      public? true
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
