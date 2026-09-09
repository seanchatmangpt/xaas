defmodule Xaas.Operations.RouteCastleRun do
  @moduledoc """
  XaaS capability surface for CASTLE execution.

  Reads remain the existing generated/public projection. The private `:execute`
  generic action is intentionally not routed through JSON:API or GraphQL. It can
  succeed only when called from `Xaas.Actuation`, because `Xaas.Castle.Admission`
  verifies the exact persisted outer intent and prepared receipt before CASTLE
  receives an O* witness.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # The private execute action is NOT carved out here: Xaas.Actuation calls
    # it with authorize?: false only after manufacturing durable authority
    # context, and the action independently verifies that context against DB.
    bypass action_type(:read) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :route_castle_run
  end

  json_api do
    type "route_castle_run"

    routes do
      base "/route_castle_run"
      get :read
      index :read
    end
  end

  postgres do
    table "route_castle_runs"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    action :execute, :map do
      public? false
      transaction? true

      argument :intent, :map do
        allow_nil? false
      end

      run Xaas.Castle.Actions.Execute
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :requested_by, :string do
      allow_nil? false
    end

    attribute :approved_by, :string
  end
end
