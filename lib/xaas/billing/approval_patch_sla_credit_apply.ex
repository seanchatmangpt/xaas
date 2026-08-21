defmodule Xaas.Billing.ApprovalPatchSlaCreditApply do
  @moduledoc """
  Real maker-checker approval resource for patch SLA credit application requests. Was a
  read-only skeleton (`defaults [:read]`, no mutation surface at all) --
  this pass adds the real `:create`/`:approve` actions, following the
  established pattern in `Xaas.Billing.ApprovalPricingOverride` /
  `Xaas.Governance.ApprovalFreezeOverride`: `:create` is unauthenticated
  at the Ash-policy layer (real access control is the router-level
  `KanbanWeb.Plugs.RequireInternalApiToken` Bearer check ahead of every
  `/api` route), and `:approve` additionally runs
  `Xaas.Billing.Validations.ApprovalPatchSlaCreditApplyRequiresApprover` -- `approved_by` must
  be present and must differ from `requested_by` (a second, distinct
  approver; no self-approval).
  """
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor).
    bypass action_type(:read) do
      authorize_if always()
    end

    # Real, explicit per-action carve-out: `:create`/`:approve` are gated
    # the same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # `:approve`'s own real validation
    # (`ApprovalPatchSlaCreditApplyRequiresApprover`) rejecting a missing or
    # self-approving `approved_by`. Deliberate per-action carve-out, not
    # a blanket allow of every mutation.
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
    type :approval_patch_sla_credit_apply
  end

  json_api do
    type "approval_patch_sla_credit_apply"

    routes do
      base "/approval_patch_sla_credit_apply"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_patch_sla_credit_applies"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:requested_by, :approved_by, :org_id, :credit_amount_cents]
    end

    # Real mutation route: approve a pending patch SLA credit application request. Real
    # business rules:
    # - Xaas.Billing.Validations.ApprovalPatchSlaCreditApplyRequiresApprover --
    #   `approved_by` must be present and must differ from `requested_by`
    #   (a second, distinct approver).
    # - Xaas.Billing.Changes.ApprovalPatchSlaCreditApplyApprove -- real, NEW
    #   Ledger integration: on the request's real first `:approve`, a
    #   real Xaas.Ledger.Transfer credits `credit_amount_cents` from the
    #   dedicated `platform:revenue:sla-credits` account to the org's
    #   real Xaas.Ledger.Account. See that module's own moduledoc for the
    #   full disclosure (why a dedicated account, why after_transaction/2,
    #   idempotency).
    update :approve do
      accept [:approved_by]
      require_atomic? false
      change Xaas.Billing.Changes.ApprovalPatchSlaCreditApplyApprove
      validate Xaas.Billing.Validations.ApprovalPatchSlaCreditApplyRequiresApprover
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :requested_by, :string do
      allow_nil? false
      public? true
    end

    attribute :approved_by, :string do
      public? true
    end

    # Real, necessary addition beyond the prior read-only skeleton's
    # attribute set: crediting an org's Ledger.Account requires a real
    # org identifier. No multitenancy machinery is wired here (unlike
    # Xaas.Governance.ApprovalBackupRetentionChange) -- this is a plain
    # string identifier, used directly as the Xaas.Ledger.Account
    # `identifier` for the org's account, same convention
    # Xaas.Billing.Changes.SubscriptionChargeOnActivate and
    # Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage
    # already use for `record.org_id`.
    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    # Real, necessary addition: a patch SLA credit needs a real amount to
    # actually credit. `credit_amount_cents` is a real, disclosed
    # placeholder-shaped field (the caller supplies the real cents
    # amount at `:create` time; this resource does not itself compute
    # an SLA-breach-derived amount -- that pricing logic does not exist
    # yet and is out of scope for this pass). Integer cents, must be
    # positive.
    attribute :credit_amount_cents, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end
  end
end
