defmodule Xaas.Governance.ApprovalSsoRoleMappingUpdate do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :approval_sso_role_mapping_update
  end

  json_api do
    type "approval_sso_role_mapping_update"
  end

  postgres do
    table "approval_sso_role_mapping_updates"
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
