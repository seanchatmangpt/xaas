defmodule Xaas.Governance.DataDestructionCertificateIssue do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :data_destruction_certificate_issue
  end

  json_api do
    type "data_destruction_certificate_issue"
  end

  postgres do
    table "data_destruction_certificate_issues"
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
