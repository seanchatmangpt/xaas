defmodule Xaas.Governance.ApprovalSsoRoleMappingUpdate do
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
    # real PUT /api/orgs/[id]/sso-role-mapping maker-checker flow:
    # `:create` (file the requested mapping set) and `:approve` are gated
    # the same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # ApprovalSsoRoleMappingUpdateRequiresApprover's real "second,
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
    type :approval_sso_role_mapping_update
  end

  json_api do
    type "approval_sso_role_mapping_update"

    routes do
      base "/approval_sso_role_mapping_update"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_sso_role_mapping_updates"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real mutation route, ported from platform-console's real
    # PUT /api/orgs/[id]/sso-role-mapping maker-checker flow: file a
    # requested SSO-group -> app-role mapping set for maker-checker
    # approval. Structural shape validated by
    # Xaas.Governance.Validations.ApprovalSsoRoleMappingUpdateValidMappings
    # (ported verbatim from validateSsoGroupMappings in
    # app/lib/sso-role-mapping.ts).
    #
    # NOT ported: this route's own GET (fetch the org's currently-applied
    # mapping set) and its "bind exactly what was actually approved, not
    # whatever the caller resends on PUT" replay-guard behavior --
    # xaas has no equivalent live-applied-mapping store
    # (getOrgSsoGroupMappings/setOrgSsoGroupMappings) to read/write yet,
    # only this approval-request record. The :approve action below
    # records approval of the request as filed; it does not itself apply
    # the mapping anywhere.
    create :create do
      accept [:org_id, :requested_by, :requested_mappings]
      validate Xaas.Governance.Validations.ApprovalSsoRoleMappingUpdateValidMappings
    end

    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalSsoRoleMappingUpdateRequiresApprover
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

    # Real payload, matching platform-console's real PUT body
    # (`mappings: {ssoGroup: string, role: Role}[]`). Stored as a raw
    # array-of-maps rather than a normalized join table since xaas has no
    # per-mapping-entry resource of its own yet -- same "config-only,
    # declare + validate offline" scope platform-console's own
    # lib/sso-role-mapping.ts module doc documents.
    attribute :requested_mappings, {:array, :map} do
      allow_nil? false
      public? true
    end
  end
end
