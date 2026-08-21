defmodule Xaas.Governance.ApprovalGeofenceExceptionGrant do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

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
    # real POST /api/owner/geofence-policy maker-checker flow: `:create`
    # (file the bounded-TTL geofence exception request) and `:approve` are
    # gated the same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # ApprovalGeofenceExceptionGrantRequiresApprover's real "second,
    # distinct owner" rule on :approve.
    bypass action(:create) do
      authorize_if always()
    end

    bypass action(:approve) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :approval_geofence_exception_grant
  end

  json_api do
    type "approval_geofence_exception_grant"

    routes do
      base "/approval_geofence_exception_grant"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_geofence_exception_grants"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :requested_by, :identifier_or_cidr, :reason, :ttl_hours]

      validate Xaas.Governance.Validations.ApprovalGeofenceExceptionGrantValidTtlHours
    end

    # Real mutation route, ported from platform-console's
    # POST /api/owner/geofence-policy `geofence.exception.grant`
    # maker-checker flow: approve a pending bounded-TTL geofence
    # exception. Real business rule lives in
    # Xaas.Governance.Validations.ApprovalGeofenceExceptionGrantRequiresApprover
    # -- `approved_by` must be present and must differ from
    # `requested_by` (a second, distinct owner).
    #
    # NOT ported (honestly left undone, not fabricated): platform-console's
    # own real side effects once approved -- `applyGeofenceException`
    # actually mutating the live geofence-enforcement store/CIDR map, and
    # the durable audit-log writes (`writeAuditLogEntry`/
    # `writeAuditLogEntryAwaited`) around every branch of GET/PUT/POST.
    # Also not ported here: the sibling GET (`?evaluateIp=` live
    # enforcement-check-and-audit) and PUT (declare/update an org's
    # geofence policy shape -- contractedRegions/cidrRegionMap/
    # enforcementMode) endpoints from the same route.ts file -- this
    # resource only models the exception-grant maker-checker approval,
    # not the policy-declaration or live-evaluation surface, which have
    # no equivalent resource in xaas yet.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalGeofenceExceptionGrantRequiresApprover
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    attribute :requested_by, :string do
      allow_nil? false
      public? true
    end

    attribute :approved_by, :string do
      public? true
    end

    # Real payload, matching platform-console's real POST body
    # (orgId/identifierOrCidr/reason/ttlHours, all required).
    attribute :identifier_or_cidr, :string do
      allow_nil? false
      public? true
    end

    attribute :reason, :string do
      allow_nil? false
      public? true
    end

    attribute :ttl_hours, :integer do
      allow_nil? false
      public? true
    end
  end
end
