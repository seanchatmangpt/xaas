defmodule Xaas.Governance.ApprovalCmekKeyBinding do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :approval_cmek_key_binding
  end

  json_api do
    type "approval_cmek_key_binding"
  end

  postgres do
    table "approval_cmek_key_bindings"
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
