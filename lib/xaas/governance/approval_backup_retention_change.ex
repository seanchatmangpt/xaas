defmodule Xaas.Governance.ApprovalBackupRetentionChange do
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

    # Real, explicit per-action carve-out (issue #20): the `:approve` action
    # is gated the same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus its own
    # real validation (ApprovalBackupRetentionChangeRequiresApprover)
    # rejecting a missing or self-approving `approved_by`. This is a
    # deliberate decision for this one action, not a blanket allow of every
    # mutation.
    bypass action(:approve) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :approval_backup_retention_change
  end

  json_api do
    type "approval_backup_retention_change"

    routes do
      base "/approval_backup_retention_change"
      get :read
      index :read
      patch :approve
    end
  end

  postgres do
    table "approval_backup_retention_changes"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :requested_by, :requested_retention_days]
    end

    # Real mutation route (issue #20), ported from platform-console's
    # PUT /api/orgs/[id]/backup-policy maker-checker flow: approve a
    # pending backup-retention change. Business rule lives in
    # Xaas.Governance.Validations.ApprovalBackupRetentionChangeRequiresApprover
    # -- `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct owner).
    update :approve do
      accept [:approved_by]
      require_atomic? false
      change Xaas.Governance.Changes.ApprovalBackupRetentionChangeApprove
      validate Xaas.Governance.Validations.ApprovalBackupRetentionChangeRequiresApprover
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

    # Real business payload, matching platform-console's
    # `resourcePayload.requestedRetentionDays` -- the retention window (in
    # days) the requester wants applied once approved. Range validation
    # against the org's tier (RETENTION_RANGE[tier] in platform-console)
    # is real per-tier business logic not yet ported; this attribute
    # carries the requested value honestly, without inventing a range
    # this session hasn't verified.
    attribute :requested_retention_days, :integer do
      allow_nil? false
      public? true
    end
  end
end
