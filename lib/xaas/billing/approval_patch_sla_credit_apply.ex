defmodule Xaas.Billing.ApprovalPatchSlaCreditApply do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Billing,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :approval_patch_sla_credit_apply
  end

  json_api do
    type "approval_patch_sla_credit_apply"
  end

  postgres do
    table "approval_patch_sla_credit_applies"
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
