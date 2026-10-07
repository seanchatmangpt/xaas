defmodule Xaas.Platform.RouteFeatureFlags do
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Platform,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Real, explicit per-action carve-out, ported from platform-console's
    # real POST /api/feature-flags (internal/back-office toggle) and
    # PUT /api/feature-flags/[flag] (customer-facing self-service toggle)
    # routes. Both require session auth + minimum app-role "member" in
    # platform-console's own auth model (lib/authz.ts requireRole) --
    # neither route uses a second-approver/maker-checker flow, unlike the
    # Xaas.Governance cluster. Gated at the router level the same way as
    # the other Platform resources -- XaasWeb.Plugs.RequireInternalApiToken.
    bypass action(:create) do
      # XAAS-2602: real system-authority predicate replaces the bare
      # always() -- XaasWeb.Plugs.SetInternalApiSystemActor supplies the
      # Xaas.SystemAuthority.new(:internal_api) actor AFTER the
      # RequireInternalApiToken Bearer check (HTTP gate unchanged), so the
      # action no longer authorizes literally any other actor/path.
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    bypass action(:update) do
      # XAAS-2602: real system-authority predicate replaces the bare
      # always() -- XaasWeb.Plugs.SetInternalApiSystemActor supplies the
      # Xaas.SystemAuthority.new(:internal_api) actor AFTER the
      # RequireInternalApiToken Bearer check (HTTP gate unchanged), so the
      # action no longer authorizes literally any other actor/path.
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    # W792: real maker-checker approve surface -- the same internal_api
    # system-authority gate as the other mutations, plus the
    # RouteFeatureFlagsRequiresApprover validation on the action itself
    # (approved_by present and distinct from requested_by).
    bypass action(:approve) do
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    policy always() do
      forbid_if(always())
    end
  end

  json_api do
    type("route_feature_flags")

    routes do
      base("/route_feature_flags")
      get(:read)
      index(:read)
      post(:create)
      patch(:update)
      # W808 (docs/sjira/v26.10.6/plans/w808-approve-route.md), closing W785's
      # cross-lane unblock: a bare second `patch(:approve)` collides with
      # `patch(:update)` on `/:id` (ValidateNoOverlappingRoutes groups by
      # {method, route}), but the overlap check is exact-path, not
      # same-method: a ROUTE-QUALIFIED patch on a distinct path segment is
      # lawful. So `:approve` is exposed as PATCH .../:id/approve -- the
      # standard JSON:API idiom for a non-default update action -- distinct
      # from `patch(:update)`'s `/:id`, no collision, real HTTP surface for
      # the maker-checker approval.
      patch(:approve, route: ":id/approve")
    end
  end

  postgres do
    table("route_feature_flags")
    repo(Xaas.Repo)
  end

  actions do
    defaults([:read])

    # Real mutation, ported from platform-console's POST /api/feature-flags:
    # create/register a flag entry with its initial requested value.
    #
    # NOT ported (real external integration this session has no equivalent
    # for): platform-console's actual state store is a Kubernetes ConfigMap
    # (`platform-feature-flags` in namespace `platform-console`, written via
    # `createOrUpdateConfigMap`'s RFC 7386 merge patch) -- this resource
    # models the metadata/audit half only (who requested what, current
    # enabled state) as a real Postgres row; it does not talk to k8s.
    #
    # NOT ported: the real plan-tier entitlement gate (`TIER_GATED_FLAGS`,
    # `TIER_GATED_FLAG_OWNER_PROJECT`, `isFlagEntitled`/`tierAtLeast` in
    # lib/tiers.ts) that reads the flag's owning Project CR's live tier and
    # blocks turning a gated flag ON below the required tier (turning OFF is
    # always allowed). Xaas has no Project/tier resource modeled yet, so
    # `required_tier` is stored as a plain string field for future wiring
    # rather than fabricated as an enforced check.
    create :create do
      accept([:flag_key, :enabled, :requested_by, :required_tier])
    end

    # Real mutation, ported from platform-console's PUT
    # /api/feature-flags/[flag] (customer-facing toggle) and POST
    # /api/feature-flags (internal toggle) -- both just flip `enabled` for
    # an existing flag; no maker-checker gate.
    update :update do
      accept([:enabled])
      require_atomic?(false)
    end

    # W792: real maker-checker approve action -- a second, distinct actor
    # (named by `approved_by`, refused when equal to `requested_by` by the
    # validation) signs the flag. Previously the *RequiresApprover
    # validation / *Approve change shims were wired to no action anywhere.
    update :approve do
      accept([:approved_by])
      require_atomic?(false)
      validate(Xaas.Platform.Validations.RouteFeatureFlagsRequiresApprover)
      change(Xaas.Platform.Changes.RouteFeatureFlagsApprove)
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Real payload field, matching platform-console's `key` (POST body) /
    # `flag` (PUT path param).
    attribute :flag_key, :string do
      allow_nil?(false)
      public?(true)
    end

    # Real payload field, matching platform-console's `value: "true"/"false"`
    # (POST) / `enabled: boolean` (PUT) -- stored here as a real boolean.
    attribute :enabled, :boolean do
      allow_nil?(false)
      public?(true)
      default(false)
    end

    attribute :requested_by, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :approved_by, :string do
      public?(true)
    end

    # Real metadata mirroring platform-console's TIER_GATED_FLAGS lookup
    # (`requiredTier`, default "starter") -- not enforced here; see the
    # NOT ported note on :create above.
    attribute :required_tier, :string do
      public?(true)
      default("starter")
    end
  end
end
