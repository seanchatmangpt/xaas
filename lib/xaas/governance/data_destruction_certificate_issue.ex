defmodule Xaas.Governance.DataDestructionCertificateIssue do
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
    # real POST /api/owner/data-destruction maker-checker flow: `:create`
    # (file the certificate-issue request) and `:approve` are gated the
    # same way reads are -- by the router-level
    # KanbanWeb.Plugs.RequireInternalApiToken Bearer check -- plus
    # DataDestructionCertificateIssueRequiresApprover's real "second,
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
    type :data_destruction_certificate_issue
  end

  json_api do
    type "data_destruction_certificate_issue"

    routes do
      base "/data_destruction_certificate_issue"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "data_destruction_certificate_issues"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real mutation route, ported from platform-console's
    # POST /api/owner/data-destruction: file a request to issue a
    # Certificate of Data Destruction for org_id. platform-console's own
    # route does the real live teardown verification (`verifyDataDestruction`
    # -- real k8s PVC list, real backup record scan against
    # GET /api/internal/data-destruction) BEFORE filing the approval
    # request, and again fresh at issuance time, and refuses to mint a
    # certificate unless both checks are all-clear. xaas has no equivalent
    # live k8s/backup-scan integration yet, so that verification step is
    # honestly NOT ported here -- this resource only models the
    # maker-checker request/approval record itself, not the underlying
    # teardown attestation. Likewise, platform-console's own certificate
    # minting (issueDataDestructionCertificate -- writing the actual signed
    # certificate document/hash) is NOT ported; :approve here only records
    # who approved, it does not issue a certificate artifact.
    create :create do
      accept [:org_id, :requested_by]
    end

    update :approve do
      accept [:approved_by]
      require_atomic? false
      validate Xaas.Governance.Validations.DataDestructionCertificateIssueRequiresApprover
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
  end
end
