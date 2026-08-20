defmodule Xaas.Operations.ApprovalK8sFaultRemediateSuggest do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Operations,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :approval_k8s_fault_remediate_suggest
  end

  json_api do
    type "approval_k8s_fault_remediate_suggest"
  end

  postgres do
    table "approval_k8s_fault_remediate_suggests"
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
