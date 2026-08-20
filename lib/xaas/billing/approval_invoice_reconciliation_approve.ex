defmodule Xaas.Billing.ApprovalInvoiceReconciliationApprove do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Billing,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :approval_invoice_reconciliation_approve
  end

  json_api do
    type "approval_invoice_reconciliation_approve"
  end

  postgres do
    table "approval_invoice_reconciliation_approves"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]
  end

  attributes do
    uuid_primary_key :id

    attribute :requested_by, :string do
      allow_nil? false
    end

    attribute :approved_by, :string
  end
end
