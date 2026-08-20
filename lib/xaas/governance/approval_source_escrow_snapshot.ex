defmodule Xaas.Governance.ApprovalSourceEscrowSnapshot do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :approval_source_escrow_snapshot
  end

  json_api do
    type "approval_source_escrow_snapshot"
  end

  postgres do
    table "approval_source_escrow_snapshots"
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
