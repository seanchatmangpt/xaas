defmodule Xaas.Operations.CastleVerbFortune5Requirements do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Operations,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :castle_verb_fortune5_requirements
  end

  json_api do
    type "castle_verb_fortune5_requirements"
  end

  postgres do
    table "castle_verb_fortune5_requirements"
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
