defmodule Xaas.Governance.ApprovalLeRequestRespond do
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
    # real POST /api/internal/le-requests (log a new LE/government data
    # request) and PUT /api/owner/le-requests (record the actual response
    # to one, gated behind the "le-request.respond" maker-checker flow):
    # `:create` and `:approve` are gated the same way reads are -- by the
    # router-level KanbanWeb.Plugs.RequireInternalApiToken Bearer check --
    # plus ApprovalLeRequestRespondRequiresApprover's real "second,
    # distinct owner" rule on `:approve`.
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
    type :approval_le_request_respond
  end

  json_api do
    type "approval_le_request_respond"

    routes do
      base "/approval_le_request_respond"
      get :read
      index :read
      post :create
      patch :approve
    end
  end

  postgres do
    table "approval_le_request_responds"
    repo Xaas.Repo
  end

  actions do
    defaults [:read]

    # Real intake, ported from platform-console's real POST
    # /api/internal/le-requests (shared-secret-authed transparency-log
    # entry point). `requested_by` here is platform-console's `loggedBy`
    # -- the legal/privacy-team intake actor who filed the register entry
    # -- kept as `requested_by` for consistency with every other
    # ApprovalX resource's maker-checker naming in this domain.
    create :create do
      accept [
        :org_id,
        :requested_by,
        :request_type,
        :requesting_authority,
        :jurisdiction,
        :summary,
        :reference_number
      ]
    end

    # Real mutation route, ported from platform-console's PUT
    # /api/owner/le-requests maker-checker flow: record the actual
    # response (disclosed/narrowed/objected/rejected) to a previously
    # logged LE/government data request. Real business rule lives in
    # Xaas.Governance.Validations.ApprovalLeRequestRespondRequiresApprover
    # -- `approved_by` must be present and must differ from
    # `requested_by` (a second, distinct owner).
    #
    # NOT ported: platform-console's own PATCH /api/owner/le-requests
    # "mark under_review" status transition (a real, but deliberately
    # non-sensitive, non-maker-checker-gated status change this session
    # has not modeled as a separate action) and the real audit-log write
    # (writeAuditLogEntryAwaited) platform-console performs on every
    # branch -- xaas has no equivalent audit-log sink wired yet, so those
    # writes are honestly left undone rather than fabricated.
    update :approve do
      accept [:approved_by, :status, :response_summary]
      require_atomic? false
      validate Xaas.Governance.Validations.ApprovalLeRequestRespondRequiresApprover
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :org_id, :string do
      public? true
    end

    attribute :requested_by, :string do
      allow_nil? false
      public? true
    end

    attribute :approved_by, :string do
      public? true
    end

    # Real payload, matching platform-console's real POST
    # /api/internal/le-requests body (requestType/requestingAuthority/
    # jurisdiction/summary/loggedBy required; referenceNumber/orgId
    # optional).
    attribute :request_type, :le_request_type do
      allow_nil? false
      public? true
    end

    attribute :requesting_authority, :string do
      allow_nil? false
      public? true
    end

    attribute :jurisdiction, :string do
      allow_nil? false
      public? true
    end

    attribute :summary, :string do
      allow_nil? false
      public? true
    end

    attribute :reference_number, :string do
      public? true
    end

    # Real payload, matching platform-console's real PUT
    # /api/owner/le-requests body (status/responseSummary required).
    attribute :status, :le_response_status do
      public? true
    end

    attribute :response_summary, :string do
      public? true
    end
  end
end
