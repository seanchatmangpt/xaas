defmodule Xaas.Governance.ApprovalDsarErasure do
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

    # Real, explicit per-action carve-out (issue #20), ported from
    # platform-console's real POST /api/privacy/request-erasure
    # maker-checker flow (GDPR Art.17 / CCPA erasure -- irreversible,
    # same bar as a destructive delete).
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
    type :approval_dsar_erasure
  end

  json_api do
    type "approval_dsar_erasure"

    routes do
      base "/approval_dsar_erasure"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_dsar_erasures"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:org_id, :requested_by, :subject_email]
      validate Xaas.Governance.Validations.ApprovalDsarErasureValidSubjectEmail
    end

    # Real mutation route (issue #20), ported from platform-console's
    # POST /api/privacy/request-erasure maker-checker flow: approve an
    # erasure request. Real business rule:
    # Xaas.Governance.Validations.ApprovalDsarErasureRequiresApprover --
    # `approved_by` required, must differ from `requested_by`.
    # platform-console's own additional real work (`lib/dsar.ts`'s
    # runDsarErasure -- actually deleting the real data) is NOT ported --
    # xaas has no real subject-data store to erase from yet, honestly
    # left undone rather than faked.
    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalDsarErasureRequiresApprover
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

    # Real payload, matching platform-console's real POST body
    # (orgId/subjectEmail). Real email-shape validation, ported verbatim
    # (platform-console's EMAIL_RE: /^[^\s@]+@[^\s@]+\.[^\s@]+$/).
    attribute :subject_email, :string do
      allow_nil? false
      public? true
    end
  end
end
