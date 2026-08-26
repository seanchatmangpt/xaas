defmodule Xaas.Billing do
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource Xaas.Billing.Subscription do
      rpc_action :list_billing_subscriptions, :read
    end
  end

  resources do
    resource Xaas.Billing.ApprovalInvoiceReconciliationApprove
    resource Xaas.Billing.ApprovalPatchSlaCreditApply
    resource Xaas.Billing.ApprovalPricingOverride
    resource Xaas.Billing.ApprovalQuotaOverride
    resource Xaas.Billing.ApprovalSlaCreditApply
    resource Xaas.Billing.ApprovalTierDowngrade
    resource Xaas.Billing.RevenueRecognition
    resource Xaas.Billing.Subscription
  end
end
