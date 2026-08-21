defmodule Xaas.Governance.ApprovalOrgDelete do
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
    # real DELETE /api/orgs/[id] maker-checker flow: `:create` (file the
    # deletion request) and `:approve` are gated the same way reads are --
    # by the router-level KanbanWeb.Plugs.RequireInternalApiToken Bearer
    # check -- plus ApprovalOrgDeleteRequiresApprover's real "second,
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
    type :approval_org_delete
  end

  json_api do
    type "approval_org_delete"

    routes do
      base "/approval_org_delete"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_org_deletes"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :requested_by]
    end

    # Real mutation route, ported from platform-console's real
    # DELETE /api/orgs/[id] maker-checker flow: approve a pending org
    # deletion. Real business rule lives in
    # Xaas.Governance.Validations.ApprovalOrgDeleteRequiresApprover --
    # `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct owner).
    #
    # NOT ported: the real route's own additional preconditions/side
    # effects, honestly left undone rather than fabricated --
    #   1. Requester's own role check (requireRoleIn(session, org's
    #      namespace, "owner")) -- xaas has no session/namespace-role
    #      model wired to this resource yet.
    #   2. The real deleteOrg(id) side effect that tears down the org's
    #      real Namespace/Project/Database/Secret/ConfigMap resources on
    #      approval -- xaas's :approve action only records the approval
    #      decision; no cascading destroy is triggered.
    #   3. The real audit-log entry (writeAuditLogEntry) written on every
    #      branch of the platform-console route.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalOrgDeleteRequiresApprover
    end
  end

  attributes do
    uuid_primary_key :id

    # Real payload, matching platform-console's real route: the target
    # org's id (the `[id]` path param on DELETE /api/orgs/[id]).
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
  end
end
