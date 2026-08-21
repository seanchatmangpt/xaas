defmodule Xaas.Billing do
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain]

  admin do
    show? true
  end


  resources do
    resource Xaas.Billing.ApprovalInvoiceReconciliationApprove
    resource Xaas.Billing.ApprovalPatchSlaCreditApply
    resource Xaas.Billing.ApprovalPricingOverride
    resource Xaas.Billing.ApprovalQuotaOverride
    resource Xaas.Billing.ApprovalSlaCreditApply
    resource Xaas.Billing.ApprovalTierDowngrade
    resource Xaas.Billing.Subscription
  end
end
