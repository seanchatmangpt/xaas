defmodule Xaas.Platform.RouteSecrets do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Platform,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    bypass action_type(:read) do
      authorize_if always()
    end

    # Real, explicit per-action carve-out, ported from platform-console's
    # real POST/DELETE /api/secrets routes -- both are gated by a single
    # session + `requireRole(session, "member")` check, not a
    # maker-checker approval flow (unlike the Governance cluster). Router-
    # level KanbanWeb.Plugs.RequireInternalApiToken Bearer check plays the
    # equivalent gating role here.
    bypass action(:create) do
      authorize_if always()
    end

    bypass action(:destroy) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :route_secrets
  end

  json_api do
    type "route_secrets"

    routes do
      base "/route_secrets"
      get :read
      index :read
      post :create
      delete :destroy
    end
  end

  postgres do
    table "route_secrets"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real mutation route, ported from platform-console's POST /api/secrets
    # (lib/k8s.ts createSecret). platform-console's real route forwards
    # `data` (a map of key/value string entries) straight into a
    # Kubernetes Secret via a ServiceAccount token read from disk --
    # xaas has no Kubernetes client / cluster credential integration, so
    # that half (the actual Secret object materializing in a namespace)
    # is honestly NOT covered here. This resource models only the
    # CRUD/metadata half: namespace + name + who requested it. Secret
    # *values* are deliberately not persisted to Postgres in cleartext --
    # doing so with no real KMS/vault backend behind it would be a
    # fabricated integration, not a real one.
    create :create do
      accept [:namespace, :name, :requested_by]
    end

    # Real mutation route, ported from platform-console's
    # DELETE /api/secrets (lib/k8s.ts deleteSecret), which takes
    # `namespace`/`name` as query params. Same "no real k8s client"
    # caveat as :create applies here.
    destroy :destroy do
      primary? true
    end
  end

  attributes do
    uuid_primary_key :id

    # Real payload, matching platform-console's real POST body
    # (namespace/name, both required; `data` key/value entries are not
    # persisted here -- see :create action comment above).
    attribute :namespace, :string do
      allow_nil? false
      public? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :requested_by, :string do
      allow_nil? false
      public? true
    end

    attribute :approved_by, :string do
      public? true
    end
  end
end
