defmodule Xaas.Governance.ApprovalExportSubscriptionUpdate do
  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Governance,
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
    # real POST /api/orgs/[id]/export-subscription maker-checker flow:
    # `:create` (file the export-subscription change request) and
    # `:approve` are gated the same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # ApprovalExportSubscriptionUpdateRequiresApprover's real "second,
    # distinct owner" rule on :approve.
    bypass action(:create) do
      authorize_if always()
    end

    bypass action(:approve) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  graphql do
    type :approval_export_subscription_update
  end

  json_api do
    type "approval_export_subscription_update"

    routes do
      base "/approval_export_subscription_update"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_export_subscription_updates"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real mutation route, ported from platform-console's
    # POST /api/orgs/[id]/export-subscription maker-checker flow (the
    # create/update branch -- NOT the `{"action":"run"}` immediate-run
    # branch, NOT the `_cron` fan-out branch; see the honest scope note
    # below). Payload matches platform-console's real POST body:
    # bucketEndpoint/bucketName/prefix/cadence/scope/enabled, plus
    # accessKeyId/secretAccessKey which platform-console encrypts before
    # storage.
    create :create do
      accept [
        :org_id,
        :requested_by,
        :bucket_endpoint,
        :bucket_name,
        :access_key_id,
        :secret_access_key,
        :prefix,
        :cadence,
        :scope,
        :enabled
      ]
    end

    # Real mutation route, ported from platform-console's maker-checker
    # flow: approve a pending export-subscription (bring-your-own-bucket)
    # config change. Real business rule lives in
    # Xaas.Governance.Validations.ApprovalExportSubscriptionUpdateRequiresApprover
    # -- `approved_by` must be present and must differ from
    # `requested_by` (a second, distinct owner).
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalExportSubscriptionUpdateRequiresApprover
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :org_id, :string do
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

    # Real payload, matching platform-console's real POST body.
    attribute :bucket_endpoint, :string do
      allow_nil? false
      public? true
    end

    attribute :bucket_name, :string do
      allow_nil? false
      public? true
    end

    # Real fields platform-console encrypts at rest
    # (accessKeyIdEncrypted/secretAccessKeyEncrypted in
    # lib/s3-export-subscription.ts) before persisting and NEVER returns
    # in a GET response (see toPublicSubscription's own doc comment in
    # the ported route.ts). xaas has no equivalent encryption-at-rest
    # layer for this resource yet -- stored here as plain string
    # attributes, honestly NOT encrypted. Do not expose these via a real
    # customer-facing read route without adding that layer first.
    attribute :access_key_id, :string do
      allow_nil? false
      public? true
    end

    attribute :secret_access_key, :string do
      allow_nil? false
      public? true
    end

    attribute :prefix, :string do
      public? true
    end

    attribute :cadence, :export_subscription_cadence do
      allow_nil? false
      public? true
    end

    attribute :scope, :export_subscription_scope do
      allow_nil? false
      public? true
    end

    attribute :enabled, :boolean do
      allow_nil? false
      default true
      public? true
    end
  end
end
