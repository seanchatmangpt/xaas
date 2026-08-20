defmodule Xaas.Platform.RouteFeatureFlags do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :route_feature_flags
  end

  json_api do
    type "route_feature_flags"
  end

  postgres do
    table "route_feature_flags"
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
