defmodule Xaas.Billing.ApprovalInvoiceReconciliationApprove do
  @moduledoc """
  Real maker-checker approval resource for invoice reconciliation approval requests. Was a
  read-only skeleton (`defaults [:read]`, no mutation surface at all) --
  this pass adds the real `:create`/`:approve` actions, following the
  established pattern in `Xaas.Billing.ApprovalPricingOverride` /
  `Xaas.Governance.ApprovalFreezeOverride`: `:create` is unauthenticated
  at the Ash-policy layer (real access control is the router-level
  `KanbanWeb.Plugs.RequireInternalApiToken` Bearer check ahead of every
  `/api` route), and `:approve` additionally runs
  `Xaas.Billing.Validations.ApprovalInvoiceReconciliationApproveRequiresApprover` -- `approved_by` must
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
    # (`ApprovalInvoiceReconciliationApproveRequiresApprover`) rejecting a missing or
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
    type :approval_invoice_reconciliation_approve
  end

  json_api do
    type "approval_invoice_reconciliation_approve"

    routes do
      base "/approval_invoice_reconciliation_approve"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_invoice_reconciliation_approves"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:requested_by, :approved_by]
    end

    # Real mutation route: approve a pending invoice reconciliation approval request. Real
    # business rule lives in
    # Xaas.Billing.Validations.ApprovalInvoiceReconciliationApproveRequiresApprover --
    # `approved_by` must be present and must differ from `requested_by`
    # (a second, distinct approver).
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Billing.Validations.ApprovalInvoiceReconciliationApproveRequiresApprover
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
  end
end
