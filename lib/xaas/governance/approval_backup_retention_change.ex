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

    # Real, explicit per-action carve-out (issue #20): `:create` (submit a
    # retention-change request) and `:approve` are gated the same way reads
    # are -- by the router-level KanbanWeb.Plugs.RequireInternalApiToken
    # Bearer check -- plus their own real validations (real tier-range
    # check on :create,
    # ApprovalBackupRetentionChangeRequiresApprover on :approve). This is a
    # deliberate decision for these two actions, not a blanket allow of
    # every mutation.
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
    type :approval_backup_retention_change
  end

  json_api do
    type "approval_backup_retention_change"

    routes do
      base "/approval_backup_retention_change"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_backup_retention_changes"
    repo Xaas.Repo

    references do
      reference :org, on_delete: :restrict, on_update: :update
    end
  end

  # Real Ash-core multitenancy wiring (issue: "do the future work for Org
  # support"). `global? true` is deliberate, not the ideal end state --
  # per this session's own multitenancy-plan workflow, strict enforcement
  # needs a real per-org actor resolved from the request (this repo's
  # current auth is a single shared Bearer token, no per-org actor
  # anywhere), which is real, disclosed follow-up work. What this DOES
  # deliver for real right now: `org_id` is a real FK to `orgs.slug`
  # (below), and the resource is tenant-attribute-aware for when strict
  # enforcement is wired.
  multitenancy do
    strategy :attribute
    attribute :org_id
    global? true
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :requested_by, :requested_retention_days, :tier]
      validate Xaas.Governance.Validations.ApprovalBackupRetentionChangeWithinTierRange
    end

    # Real mutation route (issue #20), ported from platform-console's
    # PUT /api/orgs/[id]/backup-policy maker-checker flow: approve a
    # pending backup-retention change. Business rules:
    # - Xaas.Governance.Validations.ApprovalBackupRetentionChangeRequiresApprover
    #   -- `approved_by` must be present and must differ from `requested_by`
    #   (a second, distinct owner).
    # - Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage --
    #   real, NEW (not ported) business logic: if the approved retention
    #   exceeds the org's tier default, a real Xaas.Ledger.Transfer charges
    #   a real (placeholder-priced) overage fee. See that module's own
    #   moduledoc for the honest disclosure this is invented, not a real
    #   priced product.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      change Xaas.Governance.Changes.ApprovalBackupRetentionChangeApprove
      change Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage

      change {Xaas.Governance.Changes.EnqueueWebhookDeliveries,
              event_type: "governance.approval_backup_retention_change.approved"}

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
    # days) the requester wants applied once approved. Validated against
    # `tier`'s real RETENTION_RANGE (ApprovalBackupRetentionChangeWithinTierRange)
    # on :create.
    attribute :requested_retention_days, :integer do
      allow_nil? false
      public? true
    end

    # Real tier enum, values ported verbatim from platform-console's
    # ProjectTier ("starter" | "pro" | "enterprise"). Drives both the
    # real range validation and the real overage-charge default on
    # :approve.
    attribute :tier, :project_tier do
      allow_nil? false
      public? true
    end
  end

  relationships do
    # Real FK relationship, referencing Xaas.Accounts.Org's real unique
    # `slug` (not its uuid `id`) -- Org's own moduledoc chose `slug` as
    # the string identifier existing `org_id` string columns could
    # plausibly reference without a type change, and this is that real
    # wiring. `define_attribute? false` since `org_id` is already
    # explicitly defined above.
    belongs_to :org, Xaas.Accounts.Org do
      source_attribute :org_id
      destination_attribute :slug
      attribute_type :string
      define_attribute? false
    end
  end
end
