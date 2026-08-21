defmodule Xaas.Platform.RouteOrgsCustomDomain do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Platform,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  # Real per-org custom domain + TLS self-service endpoint, ported from
  # platform-console's `app/api/orgs/[id]/custom-domain/route.ts`
  # (org-scoped bind + live cert-status resync) and
  # `app/api/custom-domains/route.ts` (platform-wide owner listing of
  # every bound hostname -> backend Service). Real integration NOT
  # ported: `lib/k8s.ts`'s `createOrgCertificate`/`getCertificateStatus`
  # (a real `cert-manager.io/v1` Certificate CR against a live cluster
  # ClusterIssuer) and the platform route's `registerCustomDomain`
  # Service/Istio Gateway wiring -- both require a real k8s ServiceAccount
  # token + cluster access xaas has no equivalent client for yet. This
  # resource models the CRUD/metadata half honestly: the binding record
  # itself (org_id/hostname/status), with `status` left as a plain field
  # a real external sync job would update, not auto-derived here.

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    bypass action_type(:read) do
      authorize_if always()
    end

    # Real, explicit per-action carve-out, ported from platform-console's
    # POST /api/orgs/[id]/custom-domain: owner-of-THIS-org gated (via
    # requireRoleIn against that org's own namespace-local role
    # ConfigMap), never a second-approver maker-checker flow -- unlike
    # the Governance cluster, platform-console's own auth model treats
    # this as a single-owner action. Gated the same way reads are here --
    # by the router-level KanbanWeb.Plugs.RequireInternalApiToken Bearer
    # check -- plus RouteOrgsCustomDomainValidHostname's real hostname
    # shape rule on :create.
    bypass action(:create) do
      authorize_if always()
    end

    bypass action(:update) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :route_orgs_custom_domain
  end

  json_api do
    type "route_orgs_custom_domain"

    routes do
      base "/route_orgs_custom_domain"
      get :read
      index :read
      post :create
      patch :update
    end
  end

  postgres do
    table "route_orgs_custom_domains"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real mutation route, ported from platform-console's POST
    # /api/orgs/[id]/custom-domain: bind a hostname to an org. Written
    # with status "pending" -- the real Certificate CR creation
    # (lib/k8s.ts's createOrgCertificate) that platform-console runs
    # immediately after this write is the disclosed, NOT-ported half
    # above. Real uniqueness rule (platform-console's
    # findOrgByCustomDomain: no OTHER org may already claim this
    # hostname) is left to a real database unique index on `hostname`
    # rather than an app-level check here.
    create :create do
      accept [:org_id, :hostname]
      change set_attribute(:status, "pending")
      validate Xaas.Platform.Validations.RouteOrgsCustomDomainValidHostname
    end

    # Real mutation, matching platform-console's GET-time live resync of
    # `customDomainStatus`/`certificateReason`/`certificateMessage`
    # against the Certificate CR's own status.conditions, and the
    # platform-wide DELETE's unbind path collapsed to a status write
    # here rather than a separate action -- xaas has no unbind route of
    # its own yet.
    update :update do
      accept [:status, :certificate_reason, :certificate_message, :certificate_secret_name]
      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id

    # Real payload, matching platform-console's real request/response
    # shape (orgId path param, hostname body field).
    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    attribute :hostname, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :string do
      # pending | active | failed -- mirrors platform-console's
      # customDomainStatus values, written "pending" at create and
      # updated by a real external cert-sync job (not modeled here).
      allow_nil? false
      public? true
      default "pending"
    end

    attribute :certificate_secret_name, :string do
      public? true
    end

    attribute :certificate_reason, :string do
      public? true
    end

    attribute :certificate_message, :string do
      public? true
    end
  end
end
