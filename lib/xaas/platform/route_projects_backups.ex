defmodule Xaas.Platform.RouteProjectsBackups do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :route_projects_backups
  end

  json_api do
    type "route_projects_backups"
  end

  postgres do
    table "route_projects_backups"
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
