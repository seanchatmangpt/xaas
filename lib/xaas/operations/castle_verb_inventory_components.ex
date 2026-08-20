defmodule Xaas.Operations.CastleVerbInventoryComponents do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Operations,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :castle_verb_inventory_components
  end

  json_api do
    type "castle_verb_inventory_components"
  end

  postgres do
    table "castle_verb_inventory_components"
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
