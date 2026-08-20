defmodule Xaas.Governance.ApprovalSubprocessorRegistryUpdate do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :approval_subprocessor_registry_update
  end

  json_api do
    type "approval_subprocessor_registry_update"
  end

  postgres do
    table "approval_subprocessor_registry_updates"
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
