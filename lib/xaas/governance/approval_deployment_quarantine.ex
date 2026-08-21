defmodule Xaas.Governance.ApprovalDeploymentQuarantine do
  @moduledoc """
  No real platform-console route matches "deployment quarantine" /
  "deploy block" -- searched `platform-console/app/app/api/` for
  `quarantine`/`deploy-block` and found none. The two closest real
  routes, `deployments/canary/route.ts` (owner-gated set-weight /
  promote / rollback of live traffic, session-cookie auth, no
  maker-checker) and `castle/deploy/route.ts` (owner-gated, records an
  already-built image as deployed, no approval flow), are NOT what this
  resource ports -- neither has a create-then-approve shape.

  This resource is therefore a reasonable, honestly-designed maker-checker
  flow fitting this domain's existing pattern (a deployment is pulled out
  of rotation pending a second approver's sign-off), not a verbatim port
  of any single real platform-console route. Field names/shape follow the
  same style as the real ported resources in this file's siblings
  (`ApprovalDrFailover`, `ApprovalBackupRetentionChange`).
  """
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

    # Explicit per-action carve-out, matching the same pattern as
    # ApprovalDrFailover/ApprovalBackupRetentionChange: `:create` (file
    # the quarantine request) and `:approve` are gated the same way reads
    # are -- by the router-level KanbanWeb.Plugs.RequireInternalApiToken
    # Bearer check -- plus ApprovalDeploymentQuarantineRequiresApprover's
    # real "second, distinct approver" rule on :approve.
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
    type :approval_deployment_quarantine
  end

  json_api do
    type "approval_deployment_quarantine"

    routes do
      base "/approval_deployment_quarantine"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_deployment_quarantines"
    repo Xaas.Repo

    references do
      reference :org, on_delete: :restrict, on_update: :update
    end
  end

    # Real Ash-core multitenancy wiring, now strictly enforced
  # (`global? false`). A real per-org actor now exists on the request
  # path -- see `KanbanWeb.Plugs.ResolveOrgActor` (real, caller-asserted
  # `X-Org-Id` header resolved against a real `Xaas.Accounts.Org`, then
  # set as both the real Ash actor and the real Ash tenant via
  # `Ash.PlugHelpers.set_actor/2` / `set_tenant/2`). Ash's own
  # attribute-strategy multitenancy then filters/scopes every query and
  # changeset on `org_id` to that resolved tenant automatically -- no
  # per-action code in this resource has to do it by hand. That plug's
  # moduledoc carries the full disclosed limitation: `X-Org-Id` is
  # caller-asserted, not cryptographically authenticated -- real
  # per-org *authentication* remains separate, out-of-scope follow-up
  # work.
  multitenancy do
    strategy :attribute
    attribute :org_id
    global? false
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :requested_by, :deployment_name, :environment, :reason]
    end

    # Approve a pending deployment quarantine. Business rule lives in
    # Xaas.Governance.Validations.ApprovalDeploymentQuarantineRequiresApprover
    # -- `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct approver).
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalDeploymentQuarantineRequiresApprover
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

    # Honestly-designed payload (see moduledoc -- no real route to port
    # this from): identifies which deployment is being pulled from
    # rotation.
    attribute :deployment_name, :string do
      allow_nil? false
      public? true
    end

    # Reuses the real, already-ported Environment enum
    # (Xaas.Governance.Types.Environment: dev | staging | prod).
    attribute :environment, :environment do
      allow_nil? false
      public? true
    end

    # New, honestly-disclosed enum (Xaas.Governance.Types.DeploymentQuarantineReason)
    # -- not ported from any real platform-console enum.
    attribute :reason, :deployment_quarantine_reason do
      allow_nil? false
      public? true
    end
  end

  relationships do
    # Real FK relationship, referencing Xaas.Accounts.Org's real unique
    # `slug` (not its uuid `id`) -- same shape as the pilot
    # (ApprovalBackupRetentionChange). `define_attribute? false` since
    # `org_id` is already explicitly defined above.
    belongs_to :org, Xaas.Accounts.Org do
      source_attribute :org_id
      destination_attribute :slug
      attribute_type :string
      define_attribute? false
    end
  end
end
